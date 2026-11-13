-- Casper Training Studio — antrenman programları, vücut ölçümleri, eğitmenin üyeleri,
-- yönetici raporu (13.11.2026, stüdyo kararı).
--
-- Gizlilik (Y-05 değişikliği, Y-10): eğitmen yalnızca KENDİ ÜYELERİNİN programlarını ve
-- ölçümlerini görür/yazar. "Kendi üyesi" = eğitmenin son 90 gün içinde başlamış veya
-- gelecekteki bir dersinde iptal edilmemiş rezervasyonu olan aktif üye
-- (private.is_my_member). Profil boy/kilo/doğum tarihi, cüzdan ve paketler eğitmene
-- kapalı kalır. Kural RLS ile ve RPC'lerin içinde zorunlu kılınır.
--
-- Ölçümler sağlık verisidir (KVKK özel nitelikli veri): yayından önce aydınlatma/açık rıza
-- metni bunları kapsamalıdır (bkz. docs/BUSINESS_RULES.md §16).
--
-- Yazma yalnızca SECURITY DEFINER RPC'lerle yapılır; tablolarda yalnızca SELECT yetkisi var.
-- Kilit: program kaydı ve aktif program değişimi üye danışma kilidi (private.lock_member)
-- altında yapılır; kilit sırası (1. adım) korunur, başka satır kilidi alınmaz.

-- ---------------------------------------------------------------------------
-- Eğitmenin üyesi mi?
-- ---------------------------------------------------------------------------
create or replace function private.is_my_member(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.user_role() = 'trainer'::public.user_role, false)
    and exists (
      select 1
      from public.reservations r
      join public.classes c on c.id = r.class_id
      join public.profiles p on p.id = r.member_id
      where r.member_id = p_member_id
        and c.trainer_id = (select auth.uid())
        and c.status = 'scheduled'::public.class_status
        and r.status <> 'cancelled'::public.reservation_status
        and c.starts_at >= now() - interval '90 days'
        and p.role = 'member'::public.user_role and p.is_active)
$$;

-- Yönetici veya üyenin eğitmeni (program/ölçüm yazma ve okuma yetkisi)
create or replace function private.can_coach_member(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin() or private.is_my_member(p_member_id)
$$;

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------
create table public.workout_programs (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid not null references public.profiles (id) on delete cascade,
  title       text not null check (char_length(btrim(title)) between 1 and 80),
  goal        text check (char_length(goal) <= 200),
  notes       text check (char_length(notes) <= 2000),
  is_active   boolean not null default true,
  created_by  uuid references public.profiles (id) on delete set null, -- hazırlayan
  updated_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- Bir üyenin en fazla bir aktif programı olur
create unique index workout_programs_one_active_per_member
  on public.workout_programs (member_id) where is_active;
create index workout_programs_member_idx
  on public.workout_programs (member_id, created_at desc);

create table public.workout_program_items (
  id            uuid primary key default gen_random_uuid(),
  program_id    uuid not null references public.workout_programs (id) on delete cascade,
  day_label     text not null check (char_length(btrim(day_label)) between 1 and 40),
  exercise      text not null check (char_length(btrim(exercise)) between 1 and 120),
  sets          integer check (sets between 1 and 99),
  reps          text check (char_length(reps) <= 40),        -- "12", "8-10", "30 sn"
  rest_seconds  integer check (rest_seconds between 0 and 3600),
  note          text check (char_length(note) <= 300),
  sort_order    integer not null default 0
);
create index workout_program_items_program_idx
  on public.workout_program_items (program_id, sort_order);

create table public.body_measurements (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.profiles (id) on delete cascade,
  measured_on   date not null check (measured_on >= date '2000-01-01'),
  weight_kg     numeric(5,1) check (weight_kg between 20 and 400),
  body_fat_pct  numeric(4,1) check (body_fat_pct between 1 and 75),
  muscle_kg     numeric(5,1) check (muscle_kg between 5 and 150),
  waist_cm      numeric(5,1) check (waist_cm between 30 and 250),
  hip_cm        numeric(5,1) check (hip_cm between 30 and 250),
  chest_cm      numeric(5,1) check (chest_cm between 30 and 250),
  arm_cm        numeric(5,1) check (arm_cm between 10 and 100),
  thigh_cm      numeric(5,1) check (thigh_cm between 20 and 150),
  note          text check (char_length(note) <= 500),
  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  -- Tüm ölçüler isteğe bağlıdır ama en az biri girilmelidir
  constraint body_measurements_at_least_one check (
    num_nonnulls(weight_kg, body_fat_pct, muscle_kg, waist_cm, hip_cm,
                 chest_cm, arm_cm, thigh_cm) >= 1)
);
create index body_measurements_member_idx
  on public.body_measurements (member_id, measured_on desc, created_at desc);

create trigger workout_programs_touch before update on public.workout_programs
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: üye kendi kaydını, eğitmen kendi üyelerininkini, yönetici hepsini okur.
-- insert/update/delete politikası ve yetkisi yok: yazma yalnızca RPC ile.
-- ---------------------------------------------------------------------------
alter table public.workout_programs      enable row level security;
alter table public.workout_program_items enable row level security;
alter table public.body_measurements     enable row level security;

revoke all on public.workout_programs, public.workout_program_items,
  public.body_measurements from anon, authenticated;
grant select on public.workout_programs, public.workout_program_items,
  public.body_measurements to authenticated;

create policy workout_programs_select on public.workout_programs for select to authenticated
  using (member_id = (select auth.uid()) or private.can_coach_member(member_id));

create policy workout_program_items_select on public.workout_program_items
  for select to authenticated
  using (exists (
    select 1 from public.workout_programs wp
    where wp.id = program_id
      and (wp.member_id = (select auth.uid()) or private.can_coach_member(wp.member_id))));

create policy body_measurements_select on public.body_measurements for select to authenticated
  using (member_id = (select auth.uid()) or private.can_coach_member(member_id));

-- ---------------------------------------------------------------------------
-- Eğitmenin üyeleri. Eğitmen yalnızca kendisi için; yönetici herhangi bir eğitmen için
-- (p_trainer_id zorunlu). Yalnızca ad ve ders bilgisi döner (Y-05).
-- class_count: son 90 gün + gelecekteki iptal edilmemiş rezervasyon sayısı.
-- ---------------------------------------------------------------------------
create or replace function public.trainer_my_members(p_trainer_id uuid default null)
returns table (member_id uuid, full_name text, last_class_at timestamptz,
               next_class_at timestamptz, class_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_role    public.user_role := private.user_role();
  v_trainer uuid;
begin
  if v_uid is null or v_role is null then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if v_role = 'admin'::public.user_role then
    if p_trainer_id is null then
      raise exception 'TRAINER_REQUIRED' using errcode = 'P0001';
    end if;
    v_trainer := p_trainer_id;
  elsif v_role = 'trainer'::public.user_role
        and (p_trainer_id is null or p_trainer_id = v_uid) then
    v_trainer := v_uid;
  else
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  return query
  select r.member_id, p.full_name,
         max(c.starts_at) filter (where c.starts_at <= now()),
         min(c.starts_at) filter (where c.starts_at > now()),
         count(*)::integer
  from public.reservations r
  join public.classes c on c.id = r.class_id
  join public.profiles p on p.id = r.member_id
  where c.trainer_id = v_trainer
    and c.status = 'scheduled'::public.class_status
    and r.status <> 'cancelled'::public.reservation_status
    and c.starts_at >= now() - interval '90 days'
    and p.role = 'member'::public.user_role and p.is_active
  group by r.member_id, p.full_name
  order by p.full_name, r.member_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Antrenman programı kaydet (oluştur veya düzenle) — program + hareketler tek transaction.
-- p_items: [{"day_label":"Gün 1","exercise":"Squat","sets":3,"reps":"12",
--            "rest_seconds":60,"note":null}, ...]  (dizi sırası = sort_order)
-- p_program_id boşsa yeni program; doluysa o program güncellenir ve hareketleri değiştirilir.
-- p_is_active = true ise üyenin diğer aktif programı aynı transaction'da pasife alınır.
-- ---------------------------------------------------------------------------
create or replace function public.save_workout_program(
  p_member_id uuid,
  p_title text,
  p_goal text default null,
  p_notes text default null,
  p_items jsonb default '[]'::jsonb,
  p_program_id uuid default null,
  p_is_active boolean default true)
returns public.workout_programs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_prog    public.workout_programs;
  v_title   text := btrim(coalesce(p_title, ''));
  v_goal    text := nullif(btrim(coalesce(p_goal, '')), '');
  v_notes   text := nullif(btrim(coalesce(p_notes, '')), '');
  v_items   jsonb := coalesce(p_items, '[]'::jsonb);
  v_active  boolean := coalesce(p_is_active, true);
  v_created boolean := false;
begin
  if v_uid is null or p_member_id is null
     or not private.can_coach_member(p_member_id) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_member_id and role = 'member'::public.user_role and is_active) then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;
  if char_length(v_title) not between 1 and 80
     or jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) > 150 then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end if;

  perform private.lock_member(p_member_id);

  if p_program_id is not null then
    select * into v_prog from public.workout_programs
    where id = p_program_id and member_id = p_member_id for update;
    if not found then
      raise exception 'PROGRAM_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;

  if v_active then
    update public.workout_programs set is_active = false, updated_by = v_uid
    where member_id = p_member_id and is_active
      and (p_program_id is null or id <> p_program_id);
  end if;

  if p_program_id is null then
    insert into public.workout_programs
      (member_id, title, goal, notes, is_active, created_by, updated_by)
    values (p_member_id, v_title, v_goal, v_notes, v_active, v_uid, v_uid)
    returning * into v_prog;
    v_created := true;
  else
    update public.workout_programs
    set title = v_title, goal = v_goal, notes = v_notes, is_active = v_active,
        updated_by = v_uid
    where id = p_program_id
    returning * into v_prog;
    delete from public.workout_program_items where program_id = p_program_id;
  end if;

  begin
    insert into public.workout_program_items
      (program_id, day_label, exercise, sets, reps, rest_seconds, note, sort_order)
    select v_prog.id,
           btrim(e.item ->> 'day_label'),
           btrim(e.item ->> 'exercise'),
           (e.item ->> 'sets')::integer,
           nullif(btrim(coalesce(e.item ->> 'reps', '')), ''),
           (e.item ->> 'rest_seconds')::integer,
           nullif(btrim(coalesce(e.item ->> 'note', '')), ''),
           e.ord::integer
    from jsonb_array_elements(v_items) with ordinality as e(item, ord);
  exception
    when invalid_text_representation or numeric_value_out_of_range
         or check_violation or not_null_violation or string_data_right_truncation then
      raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end;

  perform private.audit(
    case when v_created then 'workout_program_create' else 'workout_program_update' end,
    'workout_programs', v_prog.id::text,
    jsonb_build_object('member_id', p_member_id, 'title', v_title,
                       'is_active', v_active, 'item_count', jsonb_array_length(v_items)));
  return v_prog;
end;
$$;

-- Programı aktif/pasif yap. Aktife alınırsa üyenin diğer aktif programı pasife düşer.
create or replace function public.set_workout_program_active(
  p_program_id uuid,
  p_is_active boolean)
returns public.workout_programs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_member uuid;
  v_prog   public.workout_programs;
begin
  if v_uid is null or not private.is_staff() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_is_active is null then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end if;
  select member_id into v_member from public.workout_programs where id = p_program_id;
  -- Yetkisiz eğitmene programın varlığı sızdırılmaz
  if v_member is null or not private.can_coach_member(v_member) then
    raise exception 'PROGRAM_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_member(v_member);
  select * into v_prog from public.workout_programs where id = p_program_id for update;
  if v_prog.is_active = p_is_active then
    return v_prog;
  end if;

  if p_is_active then
    update public.workout_programs set is_active = false, updated_by = v_uid
    where member_id = v_member and is_active and id <> p_program_id;
  end if;
  update public.workout_programs set is_active = p_is_active, updated_by = v_uid
  where id = p_program_id returning * into v_prog;

  perform private.audit('workout_program_set_active', 'workout_programs', p_program_id::text,
    jsonb_build_object('member_id', v_member, 'is_active', p_is_active));
  return v_prog;
end;
$$;

-- ---------------------------------------------------------------------------
-- Vücut ölçümü ekle: üye kendisi için, eğitmen kendi üyesi için, yönetici herkes için.
-- Aralıklar tablo CHECK kısıtlarıyla denetlenir (23514). Denetim kaydına ölçüm değerleri
-- yazılmaz (sağlık verisi); yalnızca üye ve tarih yazılır.
-- ---------------------------------------------------------------------------
create or replace function public.add_body_measurement(
  p_member_id uuid,
  p_measured_on date default null,
  p_weight_kg numeric default null,
  p_body_fat_pct numeric default null,
  p_muscle_kg numeric default null,
  p_waist_cm numeric default null,
  p_hip_cm numeric default null,
  p_chest_cm numeric default null,
  p_arm_cm numeric default null,
  p_thigh_cm numeric default null,
  p_note text default null)
returns public.body_measurements
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_role  public.user_role := private.user_role();
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_day   date := coalesce(p_measured_on, (now() at time zone 'Europe/Istanbul')::date);
  v_self  boolean;
  v_row   public.body_measurements;
begin
  if v_uid is null or v_role is null or p_member_id is null then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  v_self := (p_member_id = v_uid and v_role = 'member'::public.user_role);
  if not v_self and not private.can_coach_member(p_member_id) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_member_id and role = 'member'::public.user_role and is_active) then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;
  if v_day > v_today or v_day < date '2000-01-01' then
    raise exception 'INVALID_DATE' using errcode = 'P0001';
  end if;
  if num_nonnulls(p_weight_kg, p_body_fat_pct, p_muscle_kg, p_waist_cm, p_hip_cm,
                  p_chest_cm, p_arm_cm, p_thigh_cm) = 0 then
    raise exception 'MEASUREMENT_EMPTY' using errcode = 'P0001';
  end if;

  insert into public.body_measurements
    (member_id, measured_on, weight_kg, body_fat_pct, muscle_kg, waist_cm, hip_cm,
     chest_cm, arm_cm, thigh_cm, note, created_by)
  values
    (p_member_id, v_day, round(p_weight_kg, 1), round(p_body_fat_pct, 1),
     round(p_muscle_kg, 1), round(p_waist_cm, 1), round(p_hip_cm, 1),
     round(p_chest_cm, 1), round(p_arm_cm, 1), round(p_thigh_cm, 1),
     nullif(btrim(coalesce(p_note, '')), ''), v_uid)
  returning * into v_row;

  if not v_self then
    perform private.audit('body_measurement_add', 'body_measurements', v_row.id::text,
      jsonb_build_object('member_id', p_member_id, 'measured_on', v_day));
  end if;
  return v_row;
exception
  when numeric_value_out_of_range then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
end;
$$;

-- Hatalı ölçümü sil: yönetici her kaydı; üye ve eğitmen yalnızca KENDİ girdiği kaydı
-- (eğitmen için üye hâlâ kendi üyesi olmalı). Yetkisiz çağrıda varlık sızdırılmaz.
create or replace function public.delete_body_measurement(p_measurement_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_role public.user_role := private.user_role();
  v_row  public.body_measurements;
  v_ok   boolean;
begin
  if v_uid is null or v_role is null then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  select * into v_row from public.body_measurements
  where id = p_measurement_id for update;
  v_ok := found and (
    v_role = 'admin'::public.user_role
    or (v_role = 'member'::public.user_role
        and v_row.member_id = v_uid and v_row.created_by = v_uid)
    or (v_role = 'trainer'::public.user_role
        and v_row.created_by = v_uid and private.is_my_member(v_row.member_id)));
  if not coalesce(v_ok, false) then
    raise exception 'MEASUREMENT_NOT_FOUND' using errcode = 'P0002';
  end if;

  delete from public.body_measurements where id = p_measurement_id;
  if v_role <> 'member'::public.user_role then
    perform private.audit('body_measurement_delete', 'body_measurements',
      p_measurement_id::text,
      jsonb_build_object('member_id', v_row.member_id, 'measured_on', v_row.measured_on));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yönetici raporu. Aralık İstanbul gününe göre, iki uç dahil: [p_from 00:00, p_to+1 00:00).
-- Parametre boşsa içinde bulunulan ay. En fazla 366 gün.
--   package_sales   atanan paketler (activated_at): adet, tahsil edilen, liste, indirim
--   product_sales   ters kaydı alınmamış satışlar (created_at)
--   wallet_topups   ters kaydı alınmamış yüklemeler
--   members         new: aralıkta kayıt olan üye; active_with_package: ŞU AN kullanılabilir
--                   paketi olan aktif üye (aralıktan bağımsız anlık sayı)
--   classes         held: iptal edilmemiş ve başlamış; upcoming: henüz başlamamış;
--                   occupancy_pct: yapılan derslerde booked_count / capacity
--   attendance      yapılan derslerde katılan (booked) ve gelmeyen (no_show) rezervasyon
--   trainers        eğitmen bazında yapılan ders, kontenjan, katılım
--   top_products    adede göre ilk 5 ürün
-- ---------------------------------------------------------------------------
create or replace function public.admin_report(
  p_from date default null,
  p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_from  date := coalesce(p_from, date_trunc('month', (now() at time zone 'Europe/Istanbul'))::date);
  v_to    date;
  v_start timestamptz;
  v_end   timestamptz;
  v_pkg     jsonb;
  v_sales   jsonb;
  v_topup   jsonb;
  v_members jsonb;
  v_classes jsonb;
  v_att     jsonb;
  v_trainers jsonb;
  v_top     jsonb;
begin
  perform private.require_admin();
  v_to := coalesce(p_to, (date_trunc('month', v_from::timestamp) + interval '1 month - 1 day')::date);
  if v_to < v_from or v_to - v_from > 366 then
    raise exception 'INVALID_DATE_RANGE' using errcode = 'P0001';
  end if;
  v_start := v_from::timestamp at time zone 'Europe/Istanbul';
  v_end   := (v_to + 1)::timestamp at time zone 'Europe/Istanbul';

  select jsonb_build_object(
    'count', count(*),
    'total', coalesce(sum(mp.price_paid), 0),
    'list_total', coalesce(sum(mp.list_price), 0),
    'discount_total', coalesce(sum(mp.list_price - mp.price_paid), 0),
    'discounted_count', count(*) filter (where mp.discount_percent > 0))
  into v_pkg
  from public.member_packages mp
  where mp.activated_at >= v_start and mp.activated_at < v_end;

  select jsonb_build_object(
    'count', count(*) filter (where s.reversed_at is null),
    'quantity', coalesce(sum(s.quantity) filter (where s.reversed_at is null), 0),
    'total', coalesce(sum(s.total) filter (where s.reversed_at is null), 0),
    'reversed_count', count(*) filter (where s.reversed_at is not null))
  into v_sales
  from public.sales s
  where s.created_at >= v_start and s.created_at < v_end;

  select jsonb_build_object(
    'count', count(*),
    'total', coalesce(sum(wl.amount), 0))
  into v_topup
  from public.wallet_ledger wl
  where wl.entry_type = 'topup'::public.wallet_entry_type
    and wl.created_at >= v_start and wl.created_at < v_end
    and not exists (select 1 from public.wallet_ledger rv
                    where rv.reverses_entry_id = wl.id);

  select jsonb_build_object(
    'new', (select count(*) from public.profiles p
            where p.role = 'member'::public.user_role
              and p.created_at >= v_start and p.created_at < v_end),
    'active_with_package', (
      select count(distinct mp.member_id)
      from public.member_packages mp
      join public.profiles p on p.id = mp.member_id
      where mp.status = 'active'::public.package_status
        and mp.activated_at <= now() and mp.ends_at > now()
        and p.role = 'member'::public.user_role and p.is_active))
  into v_members;

  select jsonb_build_object(
    'held', count(*) filter (where c.status = 'scheduled' and c.starts_at <= now()),
    'upcoming', count(*) filter (where c.status = 'scheduled' and c.starts_at > now()),
    'cancelled', count(*) filter (where c.status = 'cancelled'),
    'capacity', coalesce(sum(c.capacity)
      filter (where c.status = 'scheduled' and c.starts_at <= now()), 0),
    'booked', coalesce(sum(c.booked_count)
      filter (where c.status = 'scheduled' and c.starts_at <= now()), 0),
    'occupancy_pct', coalesce(round(
      100.0 * sum(c.booked_count) filter (where c.status = 'scheduled' and c.starts_at <= now())
      / nullif(sum(c.capacity) filter (where c.status = 'scheduled' and c.starts_at <= now()), 0),
      1), 0))
  into v_classes
  from public.classes c
  where c.starts_at >= v_start and c.starts_at < v_end;

  select jsonb_build_object(
    'attended', count(*) filter (where r.status = 'booked'),
    'no_show', count(*) filter (where r.status = 'no_show'))
  into v_att
  from public.reservations r
  join public.classes c on c.id = r.class_id
  where c.starts_at >= v_start and c.starts_at < v_end
    and c.status = 'scheduled'::public.class_status and c.starts_at <= now();

  select coalesce(jsonb_agg(to_jsonb(t) order by t.class_count desc, t.full_name), '[]'::jsonb)
  into v_trainers
  from (
    select c.trainer_id, p.full_name,
           count(*)::integer as class_count,
           coalesce(sum(c.capacity), 0)::integer as capacity,
           coalesce(sum(c.booked_count), 0)::integer as booked,
           coalesce(sum(a.attended), 0)::integer as attended,
           coalesce(sum(a.no_show), 0)::integer as no_show
    from public.classes c
    join public.profiles p on p.id = c.trainer_id
    left join lateral (
      select count(*) filter (where r.status = 'booked') as attended,
             count(*) filter (where r.status = 'no_show') as no_show
      from public.reservations r where r.class_id = c.id) a on true
    where c.starts_at >= v_start and c.starts_at < v_end
      and c.status = 'scheduled'::public.class_status and c.starts_at <= now()
    group by c.trainer_id, p.full_name) t;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.quantity desc, t.total desc, t.name), '[]'::jsonb)
  into v_top
  from (
    select s.product_id, pr.name,
           sum(s.quantity)::integer as quantity, sum(s.total) as total
    from public.sales s
    join public.products pr on pr.id = s.product_id
    where s.created_at >= v_start and s.created_at < v_end and s.reversed_at is null
    group by s.product_id, pr.name
    order by sum(s.quantity) desc, sum(s.total) desc, pr.name
    limit 5) t;

  return jsonb_build_object(
    'from', v_from, 'to', v_to, 'generated_at', now(),
    'package_sales', v_pkg,
    'product_sales', v_sales,
    'wallet_topups', v_topup,
    'members', v_members,
    'classes', v_classes,
    'attendance', v_att,
    'trainers', v_trainers,
    'top_products', v_top);
end;
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff(),
  private.is_my_member(uuid), private.can_coach_member(uuid)
  to authenticated, service_role;

revoke all on function
  public.trainer_my_members(uuid),
  public.save_workout_program(uuid, text, text, text, jsonb, uuid, boolean),
  public.set_workout_program_active(uuid, boolean),
  public.add_body_measurement(uuid, date, numeric, numeric, numeric, numeric, numeric,
                              numeric, numeric, numeric, text),
  public.delete_body_measurement(uuid),
  public.admin_report(date, date)
from public, anon;
grant execute on function
  public.trainer_my_members(uuid),
  public.save_workout_program(uuid, text, text, text, jsonb, uuid, boolean),
  public.set_workout_program_active(uuid, boolean),
  public.add_body_measurement(uuid, date, numeric, numeric, numeric, numeric, numeric,
                              numeric, numeric, numeric, text),
  public.delete_body_measurement(uuid),
  public.admin_report(date, date)
to authenticated;
