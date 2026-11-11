-- Casper Training Studio — adım 5: dondurmayı erken bitirme, elle hak düzeltme,
-- gelmedi (no_show) işaretleme ve süresi dolan paketler için zamanlanmış görev.
--
-- Kilit sırası 20261110120200 dosyasındaki ile aynıdır:
--   1) üye danışma kilidi  2) classes satırı  3) member_packages / reservations / package_freezes

-- ---------------------------------------------------------------------------
-- Dondurmayı erken bitir / henüz başlamamış dondurmayı geri al (yalnızca yönetici)
--
-- p_last_day: dondurmanın son günü (dahil, İstanbul günü).
--   null => başlamamışsa dondurma tamamen kaldırılır; başlamışsa dün biter
--           (üye bugünden itibaren paketi kullanabilir).
-- Kaldırılan gün sayısı paket bitişinden düşülür (D-04'ün tersi).
-- Dondurma sırasında iptal edilen rezervasyonlar geri gelmez (hakları zaten iade edildi).
-- ---------------------------------------------------------------------------
create or replace function public.admin_end_freeze(
  p_freeze_id uuid,
  p_last_day date default null)
returns public.member_packages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin     uuid := private.require_admin();
  v_today     date := (now() at time zone 'Europe/Istanbul')::date;
  v_freeze    public.package_freezes;
  v_member    uuid;
  v_pkg       public.member_packages;
  v_first     date;
  v_old_last  date;
  v_new_last  date;
  v_removed   integer;
begin
  select mp.member_id into v_member
  from public.package_freezes f
  join public.member_packages mp on mp.id = f.member_package_id
  where f.id = p_freeze_id;
  if not found then
    raise exception 'FREEZE_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_member);

  select * into v_freeze from public.package_freezes where id = p_freeze_id for update;
  select * into v_pkg from public.member_packages
  where id = v_freeze.member_package_id for update;

  if v_pkg.status <> 'active'::public.package_status then
    raise exception 'PACKAGE_NOT_ACTIVE' using errcode = 'P0001';
  end if;

  v_first    := (v_freeze.starts_at at time zone 'Europe/Istanbul')::date;
  v_old_last := (v_freeze.ends_at at time zone 'Europe/Istanbul')::date - 1;

  if v_old_last < v_today then
    raise exception 'FREEZE_ALREADY_ENDED' using errcode = 'P0001';
  end if;

  v_new_last := coalesce(p_last_day, greatest(v_first, v_today) - 1);

  -- Geçmiş günler geri alınamaz; dondurma uzatılamaz (uzatma = yeni dondurma)
  if v_new_last < v_today - 1 or v_new_last < v_first - 1 or v_new_last >= v_old_last then
    raise exception 'INVALID_FREEZE_RANGE' using errcode = 'P0001';
  end if;

  v_removed := v_old_last - v_new_last;

  update public.member_packages
  set ends_at = ends_at - make_interval(days => v_removed)
  where id = v_pkg.id
  returning * into v_pkg;

  if v_new_last < v_first then
    delete from public.package_freezes where id = p_freeze_id;
  else
    update public.package_freezes
    set ends_at = (v_new_last + 1)::timestamp at time zone 'Europe/Istanbul',
        days    = days - v_removed
    where id = p_freeze_id;
  end if;

  perform private.audit('end_freeze', 'package_freezes', p_freeze_id::text,
    jsonb_build_object('package_id', v_pkg.id, 'old_last_day', v_old_last,
                       'new_last_day', v_new_last, 'removed_days', v_removed,
                       'removed', v_new_last < v_first));
  return v_pkg;
end;
$$;

-- ---------------------------------------------------------------------------
-- Elle hak düzeltme (yalnızca yönetici). Not zorunludur; hak eksiye düşmez.
-- ---------------------------------------------------------------------------
create or replace function public.admin_adjust_credits(
  p_package_id uuid,
  p_delta integer,
  p_note text)
returns public.credit_ledger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin  uuid := private.require_admin();
  v_member uuid;
  v_pkg    public.member_packages;
  v_row    public.credit_ledger;
begin
  if p_delta is null or p_delta = 0 or abs(p_delta) > 100 then
    raise exception 'INVALID_CREDIT_DELTA' using errcode = 'P0001';
  end if;
  if p_note is null or length(trim(p_note)) = 0 then
    raise exception 'NOTE_REQUIRED' using errcode = 'P0001';
  end if;

  select member_id into v_member from public.member_packages where id = p_package_id;
  if not found then
    raise exception 'PACKAGE_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_member);
  select * into v_pkg from public.member_packages where id = p_package_id for update;

  if v_pkg.remaining_credits + p_delta < 0 then
    raise exception 'NO_CREDITS' using errcode = 'P0001';
  end if;

  update public.member_packages
  set remaining_credits = remaining_credits + p_delta
  where id = p_package_id
  returning * into v_pkg;

  insert into public.credit_ledger
    (member_package_id, member_id, entry_type, delta, balance_after, note, created_by)
  values
    (v_pkg.id, v_pkg.member_id, 'adjustment', p_delta, v_pkg.remaining_credits,
     trim(p_note), v_admin)
  returning * into v_row;

  perform private.audit('adjust_credits', 'member_packages', p_package_id::text,
    jsonb_build_object('delta', p_delta, 'note', trim(p_note),
                       'balance_after', v_pkg.remaining_credits));
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Gelmedi işaretleme (yalnızca yönetici). Ek hak düşümü yapılmaz (I-06);
-- yalnızca kayıt amaçlıdır. Ders başladıktan sonra yapılır; geri alınabilir.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_no_show(
  p_reservation_id uuid,
  p_no_show boolean default true)
returns public.reservations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_res   public.reservations;
  v_class public.classes;
begin
  select * into v_res from public.reservations where id = p_reservation_id;
  if not found then
    raise exception 'RESERVATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_res.member_id);
  select * into v_class from public.classes where id = v_res.class_id for update;
  select * into v_res from public.reservations where id = p_reservation_id for update;

  if v_class.starts_at > now() then
    raise exception 'CLASS_NOT_STARTED' using errcode = 'P0001';
  end if;

  if p_no_show then
    if v_res.status = 'no_show'::public.reservation_status then
      return v_res;
    end if;
    if v_res.status <> 'booked'::public.reservation_status then
      raise exception 'RESERVATION_NOT_ACTIVE' using errcode = 'P0001';
    end if;
    update public.reservations set status = 'no_show'
    where id = p_reservation_id returning * into v_res;
  else
    if v_res.status = 'booked'::public.reservation_status then
      return v_res;
    end if;
    if v_res.status <> 'no_show'::public.reservation_status then
      raise exception 'RESERVATION_NOT_ACTIVE' using errcode = 'P0001';
    end if;
    update public.reservations set status = 'booked'
    where id = p_reservation_id returning * into v_res;
  end if;

  perform private.audit('set_no_show', 'reservations', p_reservation_id::text,
    jsonb_build_object('no_show', p_no_show));
  return v_res;
end;
$$;

-- ---------------------------------------------------------------------------
-- Süresi dolan paketleri 'expired' yap (onaylanan karar 6'daki zamanlanmış görev).
-- Kurallar zaten ends_at üzerinden anlık kontrol edilir; bu görev yalnızca durumu
-- ekranlar ve raporlar için güncel tutar.
-- ---------------------------------------------------------------------------
create or replace function private.expire_packages()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.member_packages
  set status = 'expired', closed_at = ends_at
  where status = 'active'::public.package_status and ends_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create extension if not exists pg_cron;

select cron.schedule(
  'expire-packages',
  '*/15 * * * *',
  $cron$select private.expire_packages()$cron$
);

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.admin_end_freeze(uuid, date),
  public.admin_adjust_credits(uuid, integer, text),
  public.admin_set_no_show(uuid, boolean)
from public, anon;
grant execute on function
  public.admin_end_freeze(uuid, date),
  public.admin_adjust_credits(uuid, integer, text),
  public.admin_set_no_show(uuid, boolean)
to authenticated;
