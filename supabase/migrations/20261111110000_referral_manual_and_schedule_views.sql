-- 1) Lint düzeltmesi: private.short_name IMMUTABLE değil STABLE olmalı
--    (upper() ve regexp işlemleri veritabanı yerel ayarına bağlıdır).
--    Kullananlar: public.my_referrals (STABLE) — etkilenmez.
-- 2) Yönetici elle referans ekleyebilir (BUSINESS_RULES F-16).
-- 3) Adım 4 (takvim ve rezervasyon) için okuma RPC'leri: list_classes, my_reservations.

-- ---------------------------------------------------------------------------
-- 1) short_name: STABLE
-- ---------------------------------------------------------------------------
create or replace function private.short_name(p_full_name text)
returns text
language plpgsql
stable
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

-- ---------------------------------------------------------------------------
-- 2) Yönetici elle referans ekler: onaylı olarak oluşur
-- ---------------------------------------------------------------------------
create or replace function public.admin_create_referral(
  p_referrer_id uuid,
  p_referred_id uuid,
  p_note text default null)
returns public.referrals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_code  text;
  v_ref   public.referrals;
begin
  if p_referrer_id is null or p_referred_id is null then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if p_referrer_id = p_referred_id then
    raise exception 'SELF_REFERRAL' using errcode = 'P0001';
  end if;

  select referral_code into v_code from public.profiles where id = p_referrer_id;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.profiles where id = p_referred_id) then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;

  begin
    insert into public.referrals
      (referrer_id, referred_id, code_used, status, decided_at, decided_by, decision_note)
    values
      (p_referrer_id, p_referred_id, v_code, 'approved'::public.referral_status, now(), v_admin,
       coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Yönetici tarafından elle eklendi'))
    returning * into v_ref;
  exception when unique_violation then
    -- Bir kişi yalnızca bir kez referans alabilir
    raise exception 'REFERRAL_ALREADY_EXISTS' using errcode = 'P0001';
  end;

  perform private.audit('create_referral', 'referrals', v_ref.id::text,
    jsonb_build_object('referrer_id', p_referrer_id, 'referred_id', p_referred_id,
                       'note', p_note));
  return v_ref;
end;
$$;

-- Referans eklerken kişi seçimi: yönetici tüm aktif kullanıcıları ada göre arar
-- (search_members yalnızca üyeleri döndürür; getiren eğitmen/yönetici de olabilir).
create or replace function public.admin_search_users(p_query text default '')
returns table (id uuid, full_name text, role public.user_role, referral_code text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name, p.role, p.referral_code
  from public.profiles p
  where private.is_admin()
    and p.is_active
    and (coalesce(btrim(p_query), '') = ''
         or lower(p.full_name) like '%' || lower(btrim(p_query)) || '%'
         or p.referral_code = upper(btrim(p_query)))
  order by p.full_name
  limit 50
$$;

-- ---------------------------------------------------------------------------
-- 3) Takvim: dersler + eğitmen adı + kategori adı + çağıranın rezervasyonu
--    (profiles tablosu başkalarına kapalı olduğundan eğitmen adı RPC ile gelir)
-- ---------------------------------------------------------------------------
create or replace function public.list_classes(
  p_from timestamptz,
  p_to timestamptz,
  p_category_id uuid default null,
  p_trainer_id uuid default null,
  p_include_cancelled boolean default false)
returns table (
  id uuid,
  trainer_id uuid, trainer_name text,
  category_id uuid, category_name text,
  class_type public.class_type,
  capacity integer, booked_count integer,
  title text,
  starts_at timestamptz, ends_at timestamptz,
  status public.class_status,
  my_reservation_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id,
         c.trainer_id, t.full_name,
         c.category_id, cat.name,
         c.class_type, c.capacity, c.booked_count, c.title,
         c.starts_at, c.ends_at, c.status,
         (select r.id from public.reservations r
          where r.class_id = c.id and r.member_id = (select auth.uid())
            and r.status <> 'cancelled'::public.reservation_status
          limit 1)
  from public.classes c
  join public.profiles t on t.id = c.trainer_id
  join public.categories cat on cat.id = c.category_id
  where private.user_role() is not null            -- giriş yapmış, aktif hesap
    and p_from is not null and p_to is not null
    and c.starts_at >= p_from and c.starts_at < p_to
    and p_to - p_from <= interval '93 days'
    and (p_category_id is null or c.category_id = p_category_id)
    and (p_trainer_id is null or c.trainer_id = p_trainer_id)
    and (p_include_cancelled or c.status = 'scheduled'::public.class_status)
  order by c.starts_at, c.id
  limit 1000
$$;

-- Üyenin kendi rezervasyonları (gelecek + geçmiş), ders bilgileriyle
create or replace function public.my_reservations()
returns table (
  reservation_id uuid,
  status public.reservation_status,
  booked_at timestamptz,
  cancelled_at timestamptz,
  credit_refunded boolean,
  member_package_id uuid,
  class_id uuid,
  class_status public.class_status,
  class_type public.class_type,
  title text,
  starts_at timestamptz, ends_at timestamptz,
  category_id uuid, category_name text,
  trainer_id uuid, trainer_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.status, r.booked_at, r.cancelled_at, r.credit_refunded, r.member_package_id,
         c.id, c.status, c.class_type, c.title, c.starts_at, c.ends_at,
         c.category_id, cat.name, c.trainer_id, t.full_name
  from public.reservations r
  join public.classes c on c.id = r.class_id
  join public.categories cat on cat.id = c.category_id
  join public.profiles t on t.id = c.trainer_id
  where r.member_id = (select auth.uid())
  order by c.starts_at desc, r.booked_at desc
  limit 300
$$;

-- Yönetici: bir dersin TÜM rezervasyonları (iptaller dahil) — rezervasyon yönetimi
create or replace function public.admin_class_reservations(p_class_id uuid)
returns table (
  reservation_id uuid, member_id uuid, full_name text,
  status public.reservation_status, booked_at timestamptz,
  cancelled_at timestamptz, credit_refunded boolean, cancel_reason text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.member_id, p.full_name, r.status, r.booked_at,
         r.cancelled_at, r.credit_refunded, r.cancel_reason
  from public.reservations r
  join public.profiles p on p.id = r.member_id
  where r.class_id = p_class_id and private.is_admin()
  order by (r.status = 'cancelled'::public.reservation_status), r.booked_at
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.admin_create_referral(uuid, uuid, text),
  public.admin_search_users(text),
  public.list_classes(timestamptz, timestamptz, uuid, uuid, boolean),
  public.my_reservations(),
  public.admin_class_reservations(uuid)
from public, anon;
grant execute on function
  public.admin_create_referral(uuid, uuid, text),
  public.admin_search_users(text),
  public.list_classes(timestamptz, timestamptz, uuid, uuid, boolean),
  public.my_reservations(),
  public.admin_class_reservations(uuid)
to authenticated;
