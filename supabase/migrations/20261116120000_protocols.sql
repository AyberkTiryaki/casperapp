-- Casper Training Studio — kurum protokolleri (sendika, dernek vb.) ve herkese açık fiyat listesi
-- Kurallar: BUSINESS_RULES §17 (PR-01 .. PR-12)
--
-- * Yönetici protokol tanımlar: ad, indirim oranı (%1-50), isteğe bağlı son geçerlilik günü.
-- * Yönetici üyeyi bir protokole bağlar (profiles.protocol_id); üye kendisi seçemez.
-- * Paket atamasında protokol indirimi otomatik eklenir: toplam = referans + protokol, tavan %50.
--   Uygulanan protokol ve oranı pakete kopyalanır (sonradan değişse de paket etkilenmez).
-- * public_price_list(): giriş yapmamış kişi de aktif paketleri ve geçerli protokolleri görür.

-- ---------------------------------------------------------------------------
-- Şema
-- ---------------------------------------------------------------------------
create table public.protocols (
  id                uuid primary key default gen_random_uuid(),
  name              text not null unique check (char_length(btrim(name)) between 1 and 80),
  discount_percent  integer not null check (discount_percent between 1 and 50),
  valid_until       date, -- dahil; null = süresiz (Europe/Istanbul günü)
  is_active         boolean not null default true,
  note              text check (note is null or char_length(note) <= 300),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger protocols_touch before update on public.protocols
  for each row execute function private.touch_updated_at();

alter table public.profiles
  add column protocol_id uuid references public.protocols (id) on delete set null;
create index profiles_protocol_idx on public.profiles (protocol_id) where protocol_id is not null;

-- discount_percent artık toplam orandır (referans + protokol); protokol payı ayrıca saklanır.
alter table public.member_packages
  add column protocol_id uuid references public.protocols (id) on delete set null,
  add column protocol_discount_percent integer not null default 0
    check (protocol_discount_percent between 0 and 50);

-- ---------------------------------------------------------------------------
-- Yardımcı: protokol bugün geçerli mi (aktif ve son günü geçmemiş)
-- ---------------------------------------------------------------------------
create or replace function private.protocol_is_valid(p public.protocols)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p.is_active
     and (p.valid_until is null
          or p.valid_until >= (now() at time zone 'Europe/Istanbul')::date)
$$;

-- ---------------------------------------------------------------------------
-- Yönetici: üyeyi protokole bağla / bağlantıyı kaldır (p_protocol_id null)
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_member_protocol(
  p_member_id uuid,
  p_protocol_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_old   uuid;
begin
  select protocol_id into v_old from public.profiles
  where id = p_member_id and role = 'member'::public.user_role
  for update;
  if not found then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;
  if p_protocol_id is not null and not exists (
       select 1 from public.protocols pr
       where pr.id = p_protocol_id and private.protocol_is_valid(pr)) then
    raise exception 'PROTOCOL_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_old is not distinct from p_protocol_id then
    return;
  end if;
  update public.profiles set protocol_id = p_protocol_id where id = p_member_id;
  perform private.audit('set_member_protocol', 'profiles', p_member_id::text,
    jsonb_build_object('old_protocol_id', v_old, 'protocol_id', p_protocol_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Herkese açık fiyat listesi (anon dahil). Yalnızca aktif kategori/paket ve geçerli
-- protokoller; kişisel veri ve protokol notu dönmez.
-- ---------------------------------------------------------------------------
create or replace function public.public_price_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'name', c.name, 'class_type', c.class_type,
               'packages', pk.items)
             order by c.name)
      from public.categories c
      cross join lateral (
        select jsonb_agg(jsonb_build_object(
                 'id', d.id, 'name', d.name, 'session_count', d.session_count,
                 'validity_days', d.validity_days, 'price', d.price)
               order by d.session_count, d.price) as items
        from public.package_definitions d
        where d.category_id = c.id and d.is_active) pk
      where c.is_active and pk.items is not null), '[]'::jsonb),
    'protocols', coalesce((
      select jsonb_agg(jsonb_build_object(
               'name', pr.name, 'discount_percent', pr.discount_percent,
               'valid_until', pr.valid_until)
             order by pr.discount_percent desc, pr.name)
      from public.protocols pr
      where private.protocol_is_valid(pr)), '[]'::jsonb))
$$;

-- ---------------------------------------------------------------------------
-- Paket atama: protokol indirimi eklendi (imza aynı; p_discount_percent = referans payı)
-- ---------------------------------------------------------------------------
create or replace function public.assign_package(
  p_member_id uuid,
  p_definition_id uuid,
  p_idempotency_key uuid,
  p_replace_existing boolean default false,
  p_discount_percent integer default 0)
returns public.member_packages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin    uuid := private.require_admin();
  v_now      timestamptz := now();
  v_def      public.package_definitions;
  v_old      public.member_packages;
  v_has_old  boolean := false;
  v_new      public.member_packages;
  v_new_bal  integer;
  v_old_bal  integer;
  v_discount integer := coalesce(p_discount_percent, 0);
  v_entitled integer;
  v_protocol uuid;
  v_proto_pct integer := 0;
  v_total    integer;
  v_r        record;
begin
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;

  perform private.lock_member(p_member_id);

  -- Tekrarlanan istek: aynı sonucu döndür (indirim hakkı o arada değişmiş olsa bile)
  select * into v_new from public.member_packages where idempotency_key = p_idempotency_key;
  if found then
    if v_new.member_id <> p_member_id or v_new.definition_id <> p_definition_id then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_new;
  end if;

  if not exists (select 1 from public.profiles
                 where id = p_member_id and is_active and role = 'member'::public.user_role) then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;

  select * into v_def from public.package_definitions
  where id = p_definition_id and is_active;
  if not found then
    raise exception 'DEFINITION_NOT_FOUND' using errcode = 'P0002';
  end if;

  -- Referans indirimi: yönetici 0..hak edilen oran arasında bir değer kaydedebilir
  if v_discount < 0 or v_discount > 50 then
    raise exception 'INVALID_DISCOUNT' using errcode = 'P0001';
  end if;
  if v_discount > 0 then
    v_entitled := private.referral_discount_percent(p_member_id);
    if v_discount > v_entitled then
      raise exception 'DISCOUNT_EXCEEDS_ENTITLEMENT' using errcode = 'P0001',
        hint = 'Hak edilen oran: %' || v_entitled;
    end if;
  end if;

  -- Protokol indirimi: üyenin bağlı olduğu geçerli protokolden otomatik gelir.
  -- Toplam = referans + protokol, tavan %50 (BUSINESS_RULES PR-05).
  select pr.id, pr.discount_percent into v_protocol, v_proto_pct
  from public.profiles p
  join public.protocols pr on pr.id = p.protocol_id
  where p.id = p_member_id and private.protocol_is_valid(pr);
  v_proto_pct := coalesce(v_proto_pct, 0);
  v_total := least(v_discount + v_proto_pct, 50);

  -- Bu kategorideki gelecek rezervasyonların derslerini id sırasıyla kilitle
  perform 1
  from public.classes c
  where c.starts_at > v_now
    and c.id in (
      select r.class_id
      from public.reservations r
      join public.member_packages mp on mp.id = r.member_package_id
      where r.member_id = p_member_id
        and mp.category_id = v_def.category_id
        and r.status = 'booked'::public.reservation_status)
  order by c.id
  for update of c;

  select * into v_old from public.member_packages
  where member_id = p_member_id and category_id = v_def.category_id
    and status = 'active'::public.package_status
  for update;
  v_has_old := found;

  if v_has_old then
    if v_old.ends_at > v_now and not p_replace_existing then
      -- Aynı kategoride tek aktif paket
      raise exception 'ACTIVE_PACKAGE_EXISTS' using errcode = 'P0001',
        hint = 'Yenilemek için p_replace_existing = true gönderin.';
    end if;
    update public.member_packages
    set status = case when ends_at <= v_now then 'expired'::public.package_status
                      else 'terminated'::public.package_status end,
        closed_at = v_now
    where id = v_old.id;
  end if;

  insert into public.member_packages
    (member_id, definition_id, category_id, total_credits, remaining_credits,
     list_price, discount_percent, price_paid, protocol_id, protocol_discount_percent,
     activated_at, ends_at, assigned_by, idempotency_key)
  values
    (p_member_id, v_def.id, v_def.category_id, v_def.session_count, v_def.session_count,
     v_def.price, v_total, round(v_def.price * (100 - v_total) / 100.0, 2),
     v_protocol, v_proto_pct,
     v_now, v_now + make_interval(days => v_def.validity_days),
     v_admin, p_idempotency_key)
  returning * into v_new;
  v_new_bal := v_new.remaining_credits;

  insert into public.credit_ledger
    (member_package_id, member_id, entry_type, delta, balance_after, note, created_by)
  values
    (v_new.id, p_member_id, 'grant', v_new.total_credits, v_new_bal, 'Paket atandı', v_admin);

  if v_has_old then
    update public.member_packages set replaced_by = v_new.id where id = v_old.id;

    -- Eski paketin gelecek rezervasyonları: uygunsa aktar, değilse iptal + iade
    for v_r in
      select r.id, c.starts_at
      from public.reservations r
      join public.classes c on c.id = r.class_id
      where r.member_package_id = v_old.id
        and r.status = 'booked'::public.reservation_status
        and c.starts_at > v_now
      order by c.starts_at, r.id
    loop
      if v_new_bal > 0 and v_r.starts_at < v_new.ends_at then
        -- Aktarım: eski pakete +1 (transfer_out), yeni paketten -1 (transfer_in)
        update public.member_packages set remaining_credits = remaining_credits + 1
        where id = v_old.id returning remaining_credits into v_old_bal;
        insert into public.credit_ledger
          (member_package_id, member_id, entry_type, delta, balance_after,
           reservation_id, note, created_by)
        values (v_old.id, p_member_id, 'transfer_out', 1, v_old_bal, v_r.id,
                'Rezervasyon yeni pakete aktarıldı', v_admin);

        update public.member_packages set remaining_credits = remaining_credits - 1
        where id = v_new.id returning remaining_credits into v_new_bal;
        insert into public.credit_ledger
          (member_package_id, member_id, entry_type, delta, balance_after,
           reservation_id, note, created_by)
        values (v_new.id, p_member_id, 'transfer_in', -1, v_new_bal, v_r.id,
                'Rezervasyon eski paketten aktarıldı', v_admin);

        update public.reservations set member_package_id = v_new.id where id = v_r.id;
      else
        perform private.cancel_reservation_core(
          v_r.id, true, v_admin, 'Paket yenileme: rezervasyon yeni pakete aktarılamadı');
      end if;
    end loop;

    select * into v_new from public.member_packages where id = v_new.id;
  end if;

  perform private.audit('assign_package', 'member_packages', v_new.id::text,
    jsonb_build_object('member_id', p_member_id, 'definition_id', p_definition_id,
                       'replaced', case when v_has_old then v_old.id end,
                       'list_price', v_def.price, 'discount_percent', v_total,
                       'referral_percent', v_discount, 'protocol_id', v_protocol,
                       'protocol_percent', v_proto_pct,
                       'price_paid', v_new.price_paid));
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS ve yetkiler
-- ---------------------------------------------------------------------------
alter table public.protocols enable row level security;
grant select on public.protocols to authenticated;
grant insert, update on public.protocols to authenticated; -- RLS: yalnızca yönetici
-- Üye yalnızca bağlı olduğu protokolü görür; tüm liste yöneticiye açık
-- (herkese açık liste public_price_list ile döner).
create policy protocols_select on public.protocols for select to authenticated
  using (private.is_admin()
         or id = (select p.protocol_id from public.profiles p where p.id = (select auth.uid())));
create policy protocols_admin_insert on public.protocols for insert to authenticated
  with check (private.is_admin());
create policy protocols_admin_update on public.protocols for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
-- delete politikası yok: protokol silinmez, pasife alınır (geçmiş paketler adını korur).

revoke all on function private.protocol_is_valid(public.protocols) from public, anon, authenticated;
grant execute on function private.protocol_is_valid(public.protocols) to authenticated, service_role;

revoke all on function
  public.admin_set_member_protocol(uuid, uuid),
  public.public_price_list(),
  public.assign_package(uuid, uuid, uuid, boolean, integer)
from public, anon;
grant execute on function
  public.admin_set_member_protocol(uuid, uuid),
  public.assign_package(uuid, uuid, uuid, boolean, integer)
to authenticated;
grant execute on function public.public_price_list() to anon, authenticated;
