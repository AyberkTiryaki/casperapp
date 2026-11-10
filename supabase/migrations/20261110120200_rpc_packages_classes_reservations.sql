-- Casper Training Studio — paket, ders ve rezervasyon RPC'leri
--
-- KİLİT SIRASI (kilitlenmeyi önlemek için tüm fonksiyonlar bu sıraya uyar):
--   1) üye danışma kilidi (private.lock_member)
--   2) classes satır(lar)ı — birden fazlaysa id sırasıyla
--   3) member_packages / reservations satırları
-- Bir fonksiyon sıradaki bir adımı atlayabilir, ama asla geriye dönemez.
-- reservations satırları yalnızca ilgili dersin satır kilidi tutulurken değiştirilir;
-- bu yüzden 3. adımdaki iki tablo arasındaki sıra kilitlenmeye yol açmaz.
--
-- Hata kodları: mesaj = sabit kod (ör. CLASS_FULL). Türkçe karşılıkları
-- docs/BUSINESS_RULES.md içindeki tablodadır; istemci koda göre metin gösterir.

-- Aynı üyeye ait hak/rezervasyon işlemlerini sıraya sokar (transaction sonunda bırakılır)
create or replace function private.lock_member(p_member_id uuid)
returns void
language sql
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('member:' || p_member_id::text, 0))
$$;

-- Rezervasyon iptalinin çekirdeği.
-- Ön koşul: çağıran, dersin satır kilidini tutuyor olmalı.
create or replace function private.cancel_reservation_core(
  p_reservation_id uuid, p_refund boolean, p_actor uuid, p_reason text)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res     public.reservations;
  v_balance integer;
begin
  select * into v_res from public.reservations where id = p_reservation_id for update;
  if not found then
    raise exception 'RESERVATION_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_res.status = 'cancelled'::public.reservation_status then
    return v_res; -- tekrarlanan iptal: ikinci iade yok
  end if;

  update public.reservations
  set status = 'cancelled', cancelled_at = now(), cancelled_by = p_actor,
      cancel_reason = p_reason, credit_refunded = p_refund
  where id = v_res.id
  returning * into v_res;

  update public.classes set booked_count = booked_count - 1 where id = v_res.class_id;

  if p_refund then
    update public.member_packages
    set remaining_credits = remaining_credits + 1
    where id = v_res.member_package_id
    returning remaining_credits into v_balance;

    insert into public.credit_ledger
      (member_package_id, member_id, entry_type, delta, balance_after,
       reservation_id, note, created_by)
    values
      (v_res.member_package_id, v_res.member_id, 'refund', 1, v_balance,
       v_res.id, p_reason, p_actor);
  end if;

  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- Paket atama / yenileme (yalnızca yönetici)
-- ---------------------------------------------------------------------------
create or replace function public.assign_package(
  p_member_id uuid,
  p_definition_id uuid,
  p_idempotency_key uuid,
  p_replace_existing boolean default false)
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
  v_r        record;
begin
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;

  perform private.lock_member(p_member_id);

  -- Tekrarlanan istek: aynı sonucu döndür
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
     price_paid, activated_at, ends_at, assigned_by, idempotency_key)
  values
    (p_member_id, v_def.id, v_def.category_id, v_def.session_count, v_def.session_count,
     v_def.price, v_now, v_now + make_interval(days => v_def.validity_days),
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
                       'replaced', case when v_has_old then v_old.id end));
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Paket dondurma (yalnızca yönetici). Tarihler Europe/Istanbul gününe göredir,
-- her iki gün de dahildir.
-- ---------------------------------------------------------------------------
create or replace function public.freeze_package(
  p_package_id uuid,
  p_start_date date,
  p_end_date date,
  p_note text default null)
returns public.package_freezes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin   uuid := private.require_admin();
  v_now     timestamptz := now();
  v_member  uuid;
  v_pkg     public.member_packages;
  v_start   timestamptz;
  v_end     timestamptz;
  v_days    integer;
  v_freeze  public.package_freezes;
  v_r       record;
begin
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'INVALID_FREEZE_RANGE' using errcode = 'P0001';
  end if;
  if p_start_date < (v_now at time zone 'Europe/Istanbul')::date then
    raise exception 'FREEZE_IN_PAST' using errcode = 'P0001';
  end if;
  v_days := p_end_date - p_start_date + 1;
  if v_days > 365 then
    raise exception 'INVALID_FREEZE_RANGE' using errcode = 'P0001';
  end if;
  v_start := p_start_date::timestamp at time zone 'Europe/Istanbul';
  v_end   := (p_end_date + 1)::timestamp at time zone 'Europe/Istanbul';

  select member_id into v_member from public.member_packages where id = p_package_id;
  if not found then
    raise exception 'PACKAGE_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_member);

  -- Dondurma aralığındaki rezervasyonların derslerini id sırasıyla kilitle
  perform 1
  from public.classes c
  where c.starts_at >= greatest(v_start, v_now) and c.starts_at < v_end
    and c.id in (select r.class_id from public.reservations r
                 where r.member_package_id = p_package_id
                   and r.status = 'booked'::public.reservation_status)
  order by c.id
  for update of c;

  select * into v_pkg from public.member_packages where id = p_package_id for update;
  if v_pkg.status <> 'active'::public.package_status or v_pkg.ends_at <= v_now then
    raise exception 'PACKAGE_NOT_ACTIVE' using errcode = 'P0001';
  end if;
  if v_start >= v_pkg.ends_at then
    raise exception 'FREEZE_OUTSIDE_PACKAGE' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.package_freezes f
             where f.member_package_id = p_package_id
               and f.starts_at < v_end and f.ends_at > v_start) then
    raise exception 'FREEZE_OVERLAP' using errcode = 'P0001';
  end if;

  for v_r in
    select r.id
    from public.reservations r
    join public.classes c on c.id = r.class_id
    where r.member_package_id = p_package_id
      and r.status = 'booked'::public.reservation_status
      and c.starts_at >= greatest(v_start, v_now) and c.starts_at < v_end
    order by c.id
  loop
    perform private.cancel_reservation_core(v_r.id, true, v_admin, 'Paket donduruldu');
  end loop;

  -- ONAYLANDI (10.11.2026): dondurma süresi bitiş tarihine eklenir
  update public.member_packages
  set ends_at = ends_at + make_interval(days => v_days)
  where id = p_package_id;

  insert into public.package_freezes
    (member_package_id, starts_at, ends_at, days, note, created_by)
  values (p_package_id, v_start, v_end, v_days, p_note, v_admin)
  returning * into v_freeze;

  perform private.audit('freeze_package', 'member_packages', p_package_id::text,
    jsonb_build_object('start', p_start_date, 'end', p_end_date, 'days', v_days));
  return v_freeze;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ders açma / iptal (eğitmen kendi dersi, yönetici hepsi)
-- ---------------------------------------------------------------------------
create or replace function public.create_class(
  p_category_id uuid,
  p_class_type public.class_type,
  p_starts_at timestamptz,
  p_duration_minutes integer default 60,
  p_title text default null,
  p_trainer_id uuid default null)
returns public.classes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_role    public.user_role := private.user_role();
  v_trainer uuid;
  v_end     timestamptz;
  v_class   public.classes;
begin
  if v_uid is null or v_role is null
     or v_role not in ('trainer'::public.user_role, 'admin'::public.user_role) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  if v_role = 'trainer'::public.user_role then
    if p_trainer_id is not null and p_trainer_id <> v_uid then
      raise exception 'FORBIDDEN' using errcode = '42501';
    end if;
    v_trainer := v_uid;
  else
    if p_trainer_id is null then
      raise exception 'TRAINER_REQUIRED' using errcode = 'P0001';
    end if;
    v_trainer := p_trainer_id;
  end if;

  if not exists (select 1 from public.profiles
                 where id = v_trainer and is_active and role = 'trainer'::public.user_role) then
    raise exception 'TRAINER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.categories where id = p_category_id and is_active) then
    raise exception 'CATEGORY_NOT_FOUND' using errcode = 'P0002';
  end if;
  if p_class_type is null or p_starts_at is null or p_starts_at <= now() then
    raise exception 'INVALID_CLASS_TIME' using errcode = 'P0001';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 15 and 240 then
    raise exception 'INVALID_DURATION' using errcode = 'P0001';
  end if;
  v_end := p_starts_at + make_interval(mins => p_duration_minutes);

  -- Aynı eğitmenin çakışan dersi olamaz (eğitmen bazında sıraya sok)
  perform pg_advisory_xact_lock(hashtextextended('trainer:' || v_trainer::text, 0));
  if exists (select 1 from public.classes c
             where c.trainer_id = v_trainer
               and c.status = 'scheduled'::public.class_status
               and c.starts_at < v_end and c.ends_at > p_starts_at) then
    raise exception 'TRAINER_BUSY' using errcode = 'P0001';
  end if;

  insert into public.classes
    (trainer_id, category_id, class_type, capacity, title, starts_at, ends_at, created_by)
  values
    (v_trainer, p_category_id, p_class_type,
     case when p_class_type = 'individual'::public.class_type then 1 else 6 end,
     nullif(btrim(coalesce(p_title, '')), ''), p_starts_at, v_end, v_uid)
  returning * into v_class;
  return v_class;
end;
$$;

create or replace function public.cancel_class(
  p_class_id uuid,
  p_refund boolean default true,
  p_reason text default null)
returns public.classes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_role   public.user_role := private.user_role();
  v_class  public.classes;
  v_refund boolean;
  v_r      record;
begin
  if v_uid is null or v_role is null
     or v_role not in ('trainer'::public.user_role, 'admin'::public.user_role) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select * into v_class from public.classes where id = p_class_id for update;
  if not found then
    raise exception 'CLASS_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_role = 'trainer'::public.user_role then
    if v_class.trainer_id <> v_uid then
      raise exception 'FORBIDDEN' using errcode = '42501';
    end if;
    if v_class.status = 'scheduled'::public.class_status and v_class.starts_at <= now() then
      raise exception 'CLASS_ALREADY_STARTED' using errcode = 'P0001';
    end if;
    v_refund := true; -- eğitmen iadesiz iptal edemez
  else
    v_refund := coalesce(p_refund, true);
  end if;

  if v_class.status = 'cancelled'::public.class_status then
    return v_class; -- tekrarlanan istek
  end if;

  for v_r in
    select r.id from public.reservations r
    where r.class_id = p_class_id and r.status <> 'cancelled'::public.reservation_status
    order by r.id
  loop
    perform private.cancel_reservation_core(
      v_r.id, v_refund, v_uid, coalesce(p_reason, 'Ders iptal edildi'));
  end loop;

  update public.classes
  set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid
  where id = p_class_id
  returning * into v_class;

  perform private.audit('cancel_class', 'classes', p_class_id::text,
    jsonb_build_object('refund', v_refund, 'reason', p_reason));
  return v_class;
end;
$$;

-- ---------------------------------------------------------------------------
-- Rezervasyon: kontenjan + kategori + geçerlilik + hak kontrolü ve hak düşümü
-- tek transaction içinde.
-- ---------------------------------------------------------------------------
create or replace function public.book_class(
  p_class_id uuid,
  p_idempotency_key uuid,
  p_member_id uuid default null) -- yalnızca yönetici başka üye adına gönderebilir
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_now     timestamptz := now();
  v_member  uuid;
  v_class   public.classes;
  v_pkg     public.member_packages;
  v_res     public.reservations;
  v_balance integer;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;

  v_member := coalesce(p_member_id, v_uid);
  if v_member <> v_uid then
    perform private.require_admin();
  end if;
  if not exists (select 1 from public.profiles
                 where id = v_member and is_active and role = 'member'::public.user_role) then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;

  -- 1) üye kilidi: aynı üyenin eşzamanlı/tekrarlanan istekleri sıraya girer
  perform private.lock_member(v_member);

  -- Tekrarlanan istek (idempotency): ikinci rezervasyon/düşüm yaratmadan aynı kaydı döndür
  select * into v_res from public.reservations
  where member_id = v_member and idempotency_key = p_idempotency_key;
  if found then
    if v_res.class_id <> p_class_id then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_res;
  end if;

  -- 2) ders satırı kilidi: son kontenjan tek üyeye verilir
  select * into v_class from public.classes where id = p_class_id for update;
  if not found then
    raise exception 'CLASS_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_class.status <> 'scheduled'::public.class_status then
    raise exception 'CLASS_CANCELLED' using errcode = 'P0001';
  end if;
  if v_class.starts_at <= v_now then
    raise exception 'CLASS_ALREADY_STARTED' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.reservations
             where class_id = p_class_id and member_id = v_member
               and status <> 'cancelled'::public.reservation_status) then
    raise exception 'ALREADY_BOOKED' using errcode = 'P0001';
  end if;
  if v_class.booked_count >= v_class.capacity then
    raise exception 'CLASS_FULL' using errcode = 'P0001';
  end if;

  -- 3) paket satırı kilidi: hak eksiye düşemez
  select * into v_pkg from public.member_packages
  where member_id = v_member and category_id = v_class.category_id
    and status = 'active'::public.package_status
  for update;
  if not found then
    raise exception 'NO_ACTIVE_PACKAGE' using errcode = 'P0001';
  end if;
  if v_now < v_pkg.activated_at or v_now >= v_pkg.ends_at then
    raise exception 'PACKAGE_EXPIRED' using errcode = 'P0001';
  end if;
  -- ONAYLANDI (10.11.2026): ders tarihi de paket geçerliliği içinde olmalı
  if v_class.starts_at >= v_pkg.ends_at then
    raise exception 'CLASS_AFTER_PACKAGE_END' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.package_freezes f
             where f.member_package_id = v_pkg.id
               and ((v_now >= f.starts_at and v_now < f.ends_at)
                 or (v_class.starts_at >= f.starts_at and v_class.starts_at < f.ends_at))) then
    raise exception 'PACKAGE_FROZEN' using errcode = 'P0001';
  end if;
  if v_pkg.remaining_credits <= 0 then
    raise exception 'NO_CREDITS' using errcode = 'P0001';
  end if;

  insert into public.reservations
    (class_id, member_id, member_package_id, idempotency_key, booked_by)
  values (p_class_id, v_member, v_pkg.id, p_idempotency_key, v_uid)
  returning * into v_res;

  update public.member_packages set remaining_credits = remaining_credits - 1
  where id = v_pkg.id returning remaining_credits into v_balance;

  insert into public.credit_ledger
    (member_package_id, member_id, entry_type, delta, balance_after, reservation_id, created_by)
  values (v_pkg.id, v_member, 'booking', -1, v_balance, v_res.id, v_uid);

  update public.classes set booked_count = booked_count + 1 where id = p_class_id;

  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- Rezervasyon iptali
--   Üye: yalnızca kendi rezervasyonu, derse EN AZ 2 saat varsa; hak iade edilir.
--   Yönetici: her zaman; iade edilip edilmeyeceğini p_refund ile seçmek ZORUNDADIR.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_reservation(
  p_reservation_id uuid,
  p_refund boolean default null,
  p_reason text default null)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  v_role     public.user_role := private.user_role();
  v_is_admin boolean;
  v_res      public.reservations;
  v_class    public.classes;
  v_refund   boolean;
begin
  if v_uid is null or v_role is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  v_is_admin := (v_role = 'admin'::public.user_role);

  select * into v_res from public.reservations where id = p_reservation_id;
  if not found or (not v_is_admin and v_res.member_id <> v_uid) then
    -- Başkasının rezervasyonunun varlığı sızdırılmaz
    raise exception 'RESERVATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_res.member_id);
  select * into v_class from public.classes where id = v_res.class_id for update;

  -- Kilitler alındıktan sonra güncel durumu oku (tekrarlanan iptal)
  select * into v_res from public.reservations where id = p_reservation_id;
  if v_res.status = 'cancelled'::public.reservation_status then
    return v_res;
  end if;

  if v_is_admin then
    if p_refund is null then
      raise exception 'REFUND_CHOICE_REQUIRED' using errcode = 'P0001';
    end if;
    v_refund := p_refund;
  else
    -- Tam 2 saat kala iptal edilebilir; 2 saatten az kaldıysa edilemez
    if now() > v_class.starts_at - interval '2 hours' then
      raise exception 'CANCEL_WINDOW_CLOSED' using errcode = 'P0001';
    end if;
    v_refund := true;
  end if;

  v_res := private.cancel_reservation_core(p_reservation_id, v_refund, v_uid, p_reason);

  if v_is_admin then
    perform private.audit('cancel_reservation', 'reservations', p_reservation_id::text,
      jsonb_build_object('refund', v_refund, 'reason', p_reason));
  end if;
  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.assign_package(uuid, uuid, uuid, boolean),
  public.freeze_package(uuid, date, date, text),
  public.create_class(uuid, public.class_type, timestamptz, integer, text, uuid),
  public.cancel_class(uuid, boolean, text),
  public.book_class(uuid, uuid, uuid),
  public.cancel_reservation(uuid, boolean, text)
from public, anon;
grant execute on function
  public.assign_package(uuid, uuid, uuid, boolean),
  public.freeze_package(uuid, date, date, text),
  public.create_class(uuid, public.class_type, timestamptz, integer, text, uuid),
  public.cancel_class(uuid, boolean, text),
  public.book_class(uuid, uuid, uuid),
  public.cancel_reservation(uuid, boolean, text)
to authenticated;
