-- Casper Training Studio — referans sistemi (ROADMAP §15, BUSINESS_RULES §F)
--
-- * Her profile benzersiz referral_code (kayıtta otomatik).
-- * Kayıtta isteğe bağlı kod: geçerliyse 'pending' referans oluşur; geçersiz kod kaydı
--   ENGELLEMEZ, yalnızca referans oluşmaz.
-- * Sayım = onaylı VE getirilenin şu an kullanılabilir (süresi dolmamış, dondurulmamış)
--   aktif paketi olan referanslar. İndirim = sayı x %5, tavan %50.
-- * İndirim otomatik düşülmez; yönetici paket atarken oranı (0 olabilir) kaydeder.
--   Sunucu, oranın o anki hak edilen orandan büyük olmasını engeller.

-- ---------------------------------------------------------------------------
-- Şema
-- ---------------------------------------------------------------------------
create type public.referral_status as enum ('pending', 'approved', 'rejected');

alter table public.profiles add column referral_code text;

create table public.referrals (
  id             uuid primary key default gen_random_uuid(),
  referrer_id    uuid not null references public.profiles (id) on delete cascade, -- getiren (kod sahibi)
  referred_id    uuid not null references public.profiles (id) on delete cascade, -- getirilen
  code_used      text not null,
  status         public.referral_status not null default 'pending',
  created_at     timestamptz not null default now(),
  decided_at     timestamptz,
  decided_by     uuid references public.profiles (id),
  decision_note  text,
  constraint referrals_no_self check (referrer_id <> referred_id),
  -- Bir kişi yalnızca bir kez referans alabilir
  constraint referrals_referred_once unique (referred_id)
);
create index referrals_referrer_idx on public.referrals (referrer_id, status);
create index referrals_status_idx on public.referrals (status, created_at desc);

-- Paket atamasında liste fiyatı ve uygulanan indirim oranı (snapshot)
alter table public.member_packages
  add column list_price numeric(12,2) check (list_price >= 0),
  add column discount_percent integer not null default 0
    check (discount_percent between 0 and 50);
update public.member_packages set list_price = price_paid where list_price is null;
alter table public.member_packages alter column list_price set not null;

-- ---------------------------------------------------------------------------
-- Kod üretimi: 7 karakter, karışan karakterler yok (I, L, O, 0, 1 kullanılmaz).
-- 31^7 ~ 27,5 milyar olasılık; rastgelelik gen_random_uuid() baytlarından gelir.
-- ---------------------------------------------------------------------------
create or replace function private.generate_referral_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  c_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- 31 karakter
  -- UUID v4'te 6. ve 8. baytların bir kısmı sabittir; onları kullanma
  c_positions constant integer[] := array[0, 1, 2, 3, 4, 5, 9];
  v_bytes bytea := uuid_send(gen_random_uuid());
  v_code  text := '';
  v_pos   integer;
begin
  foreach v_pos in array c_positions loop
    v_code := v_code || substr(c_alphabet, (get_byte(v_bytes, v_pos) % 31) + 1, 1);
  end loop;
  return v_code;
end;
$$;

-- Unique kısıtı backfill'den ÖNCE eklenir ki çakışma yakalanıp yeniden denensin
alter table public.profiles
  add constraint profiles_referral_code_key unique (referral_code);

-- Mevcut profillere kod ver (çakışmada yeniden dene)
do $$
declare
  v_id uuid;
  v_try integer;
begin
  for v_id in select id from public.profiles where referral_code is null loop
    v_try := 0;
    loop
      v_try := v_try + 1;
      begin
        update public.profiles set referral_code = private.generate_referral_code()
        where id = v_id;
        exit;
      exception when unique_violation then
        if v_try >= 10 then raise; end if;
      end;
    end loop;
  end loop;
end;
$$;

alter table public.profiles alter column referral_code set not null;
alter table public.profiles
  add constraint profiles_referral_code_format
  check (referral_code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{7}$');

-- "Ad S." gösterimi (üye, getirdiği kişinin yalnızca bunu görür)
create or replace function private.short_name(p_full_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_parts text[] := regexp_split_to_array(btrim(coalesce(p_full_name, '')), '\s+');
  v_n     integer := coalesce(array_length(v_parts, 1), 0);
begin
  if v_n = 0 or v_parts[1] = '' then
    return 'Üye';
  elsif v_n = 1 then
    return v_parts[1];
  end if;
  return array_to_string(v_parts[1:v_n - 1], ' ') || ' ' || upper(left(v_parts[v_n], 1)) || '.';
end;
$$;

-- Üyenin ŞU AN kullanılabilir paketi var mı? (aktif, süresi dolmamış, dondurulmamış)
create or replace function private.has_usable_package(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.member_packages mp
    where mp.member_id = p_member_id
      and mp.status = 'active'::public.package_status
      and mp.activated_at <= now()
      and mp.ends_at > now()
      and not exists (
        select 1 from public.package_freezes f
        where f.member_package_id = mp.id
          and f.starts_at <= now() and f.ends_at > now()))
$$;

-- Sayılan (onaylı + getirilenin kullanılabilir paketi olan) referans sayısı
create or replace function private.active_referral_count(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.referrals r
  where r.referrer_id = p_user_id
    and r.status = 'approved'::public.referral_status
    and private.has_usable_package(r.referred_id)
$$;

-- Hak edilen indirim oranı (%): sayı x 5, en fazla 50
create or replace function private.referral_discount_percent(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select least(private.active_referral_count(p_user_id) * 5, 50)
$$;

-- ---------------------------------------------------------------------------
-- Kayıt tetikleyicisi: profil + referans kodu + cüzdan + KVKK + (varsa) referans
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_birth    date := private.safe_date(v_meta ->> 'birth_date');
  v_height   numeric := private.safe_numeric(v_meta ->> 'height_cm');
  v_weight   numeric := private.safe_numeric(v_meta ->> 'weight_kg');
  v_version  text := nullif(btrim(coalesce(v_meta ->> 'kvkk_version', '')), '');
  v_ref_code text := upper(regexp_replace(coalesce(v_meta ->> 'referral_code', ''), '\s', '', 'g'));
  v_referrer uuid;
  v_try      integer := 0;
begin
  -- Rol HER ZAMAN 'member' başlar; metadata içindeki rol benzeri alanlar yok sayılır.
  -- Referans kodu çakışırsa (unique) yeni kodla yeniden denenir.
  loop
    v_try := v_try + 1;
    begin
      insert into public.profiles
        (id, full_name, birth_date, height_cm, weight_kg, role, referral_code)
      values (
        new.id,
        left(btrim(coalesce(v_meta ->> 'full_name', '')), 120),
        case when v_birth > date '1900-01-01' and v_birth < current_date then v_birth end,
        case when v_height between 50 and 260 then round(v_height)::integer end,
        case when v_weight between 20 and 400 then round(v_weight, 1) end,
        'member'::public.user_role,
        private.generate_referral_code()
      )
      on conflict (id) do nothing;
      exit;
    exception when unique_violation then
      if v_try >= 10 then raise; end if;
    end;
  end loop;

  insert into public.wallets (member_id) values (new.id)
  on conflict (member_id) do nothing;

  if coalesce(v_meta ->> 'kvkk_accepted', '') = 'true' and v_version is not null then
    insert into public.consents (user_id, consent_type, text_version)
    values (new.id, 'kvkk', left(v_version, 40))
    on conflict do nothing;
  end if;

  -- Referans: kod geçerliyse 'pending' kayıt. Geçersiz kod kaydı engellemez.
  if v_ref_code <> '' then
    select p.id into v_referrer
    from public.profiles p
    where p.referral_code = v_ref_code and p.id <> new.id and p.is_active;
    if v_referrer is not null then
      insert into public.referrals (referrer_id, referred_id, code_used)
      values (v_referrer, new.id, v_ref_code)
      on conflict (referred_id) do nothing;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: özet (kendi özeti; yönetici başka kullanıcı için de çağırabilir)
-- ---------------------------------------------------------------------------
create or replace function public.referral_summary(p_user_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_target uuid := coalesce(p_user_id, auth.uid());
  v_code   text;
  v_active integer;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if v_target <> v_uid and not private.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select referral_code into v_code from public.profiles where id = v_target;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  v_active := private.active_referral_count(v_target);

  return jsonb_build_object(
    'user_id', v_target,
    'referral_code', v_code,
    'active_count', v_active,
    'discount_percent', least(v_active * 5, 50),
    'approved_count', (select count(*) from public.referrals
                       where referrer_id = v_target and status = 'approved'::public.referral_status),
    'pending_count', (select count(*) from public.referrals
                      where referrer_id = v_target and status = 'pending'::public.referral_status),
    -- Bu kullanıcı birinin koduyla kayıt olmuş mu? (geçersiz kod uyarısı için)
    'was_referred', exists (select 1 from public.referrals where referred_id = v_target)
  );
end;
$$;

-- RPC: getirdiğim kişiler — yalnızca "Ad S.", durum ve şu an sayılıp sayılmadığı
create or replace function public.my_referrals()
returns table (referral_id uuid, display_name text, status public.referral_status,
               counts_now boolean, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id,
         private.short_name(p.full_name),
         r.status,
         r.status = 'approved'::public.referral_status
           and private.has_usable_package(r.referred_id),
         r.created_at
  from public.referrals r
  join public.profiles p on p.id = r.referred_id
  where r.referrer_id = (select auth.uid())
  order by r.created_at desc
$$;

-- RPC: yönetici referans paneli
create or replace function public.admin_list_referrals(
  p_status public.referral_status default null)
returns table (
  id uuid,
  referrer_id uuid, referrer_name text, referrer_code text,
  referrer_discount_percent integer,
  referred_id uuid, referred_name text,
  referred_has_active_package boolean,
  status public.referral_status,
  created_at timestamptz, decided_at timestamptz, decision_note text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id,
         r.referrer_id, pr.full_name, pr.referral_code,
         private.referral_discount_percent(r.referrer_id),
         r.referred_id, pd.full_name,
         private.has_usable_package(r.referred_id),
         r.status, r.created_at, r.decided_at, r.decision_note
  from public.referrals r
  join public.profiles pr on pr.id = r.referrer_id
  join public.profiles pd on pd.id = r.referred_id
  where private.is_admin()
    and (p_status is null or r.status = p_status)
  order by (r.status = 'pending'::public.referral_status) desc, r.created_at desc
  limit 500
$$;

-- RPC: yönetici onay / ret. Karar sonradan değiştirilebilir; her değişiklik denetim kaydına yazılır.
create or replace function public.admin_decide_referral(
  p_referral_id uuid,
  p_approve boolean,
  p_note text default null)
returns public.referrals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin  uuid := private.require_admin();
  v_ref    public.referrals;
  v_target public.referral_status;
begin
  if p_approve is null then
    raise exception 'DECISION_REQUIRED' using errcode = 'P0001';
  end if;
  v_target := case when p_approve then 'approved'::public.referral_status
                   else 'rejected'::public.referral_status end;

  select * into v_ref from public.referrals where id = p_referral_id for update;
  if not found then
    raise exception 'REFERRAL_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_ref.status = v_target then
    return v_ref; -- tekrarlanan istek
  end if;

  update public.referrals
  set status = v_target, decided_at = now(), decided_by = v_admin,
      decision_note = nullif(btrim(coalesce(p_note, '')), '')
  where id = p_referral_id
  returning * into v_ref;

  perform private.audit('decide_referral', 'referrals', p_referral_id::text,
    jsonb_build_object('status', v_target, 'note', p_note));
  return v_ref;
end;
$$;

-- ---------------------------------------------------------------------------
-- assign_package: uygulanan indirim oranı parametresi eklendi.
-- Eski 4 parametreli sürüm kaldırılır (PostgREST'te aşırı yükleme belirsizliği olmasın).
-- ---------------------------------------------------------------------------
drop function if exists public.assign_package(uuid, uuid, uuid, boolean);

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
     list_price, discount_percent, price_paid,
     activated_at, ends_at, assigned_by, idempotency_key)
  values
    (p_member_id, v_def.id, v_def.category_id, v_def.session_count, v_def.session_count,
     v_def.price, v_discount, round(v_def.price * (100 - v_discount) / 100.0, 2),
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
                       'list_price', v_def.price, 'discount_percent', v_discount,
                       'price_paid', v_new.price_paid));
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS ve yetkiler
-- ---------------------------------------------------------------------------
alter table public.referrals enable row level security;
grant select on public.referrals to authenticated;
-- Üyeler referansları yalnızca my_referrals / referral_summary RPC'leriyle görür
-- (getirilen kişinin kimliği ve kişisel verisi dönmez). Tablo yalnızca yöneticiye açık.
create policy referrals_select_admin on public.referrals for select to authenticated
  using (private.is_admin());

revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.referral_summary(uuid),
  public.my_referrals(),
  public.admin_list_referrals(public.referral_status),
  public.admin_decide_referral(uuid, boolean, text),
  public.assign_package(uuid, uuid, uuid, boolean, integer)
from public, anon;
grant execute on function
  public.referral_summary(uuid),
  public.my_referrals(),
  public.admin_list_referrals(public.referral_status),
  public.admin_decide_referral(uuid, boolean, text),
  public.assign_package(uuid, uuid, uuid, boolean, integer)
to authenticated;
