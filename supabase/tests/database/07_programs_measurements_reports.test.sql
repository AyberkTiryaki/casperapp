-- Casper Training Studio — pgTAP: eğitmenin üyeleri, antrenman programları, vücut ölçümleri, yönetici raporu
-- Kurallar: Y-04..Y-06, Y-08..Y-10, A-01..A-05, O-01..O-06, RP-01..RP-10
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(102);

-- ---------------------------------------------------------------------------
-- Ortak test yardımcıları. Her test dosyasında aynıdır; dosyalar birbirinden
-- bağımsız çalışsın diye tekrar edilir. Hepsi rollback ile silinir.
-- ---------------------------------------------------------------------------
create schema ct;
grant usage on schema ct to authenticated, anon;

-- İsimden sabit UUID üretir: ct.id('m1'), ct.id('k_rez_1') ...
create function ct.id(p_name text) returns uuid
language sql immutable as $f$
  select md5('casper-pgtap:' || p_name)::uuid
$f$;

-- auth.users kaydı açar; private.handle_new_user tetikleyicisi profil + cüzdan + KVKK
-- onayını ve sağlık verisi rızasını (ölçümler için gerekli, K-10) oluşturur. Rol, postgres olarak doğrudan güncellenir (ilk yönetici gibi).
create function ct.make_user(p_name text, p_role public.user_role default 'member')
returns uuid language plpgsql as $f$
declare
  v_id uuid := ct.id(p_name);
begin
  insert into auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
     raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
    ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
     'pgtap-' || v_id || '@example.invalid', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb,
     jsonb_build_object('full_name', 'Test ' || p_name,
                        'kvkk_accepted', 'true', 'kvkk_version', 'pgtap-1',
                        'health_consent', 'true', 'health_version', 'pgtap-1'),
     now(), now());
  if p_role <> 'member' then
    update public.profiles set role = p_role where id = v_id;
  end if;
  return v_id;
end
$f$;

-- Kullanıcı gibi davran: JWT bilgisi + authenticated rolü (transaction sonuna kadar).
-- postgres'e dönmek için: reset role;
create function ct.login(p_name text) returns void
language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', ct.id(p_name), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end
$f$;

-- İstanbul günü ve o güne göre saatler (dondurma kuralları gün bazlıdır)
create function ct.today() returns date
language sql stable as $f$
  select (now() at time zone 'Europe/Istanbul')::date
$f$;

create function ct.ist_midnight(p_day_offset integer) returns timestamptz
language sql stable as $f$
  select (ct.today() + p_day_offset)::timestamp at time zone 'Europe/Istanbul'
$f$;

create function ct.ist_noon(p_day_offset integer) returns timestamptz
language sql stable as $f$
  select ((ct.today() + p_day_offset)::timestamp + interval '12 hours')
           at time zone 'Europe/Istanbul'
$f$;

-- Dersi doğrudan ekler (create_class geçmiş/çakışan derse izin vermez; testler buna
-- ihtiyaç duyar). Süre 1 saattir.
create function ct.make_class(
  p_name text, p_trainer text, p_category text, p_starts_at timestamptz,
  p_type public.class_type default 'group')
returns uuid language sql as $f$
  insert into public.classes
    (id, trainer_id, category_id, class_type, capacity, starts_at, ends_at, created_by)
  values
    (ct.id(p_name), ct.id(p_trainer), ct.id(p_category), p_type,
     case when p_type = 'individual' then 1 else 6 end,
     p_starts_at, p_starts_at + interval '1 hour', ct.id(p_trainer))
  returning id
$f$;

-- Idempotency anahtarından kayıt kimliği (RLS'e takılmadan; yalnızca test içinde)
create function ct.pkg(p_key text) returns uuid
language sql security definer as $f$
  select id from public.member_packages where idempotency_key = ct.id(p_key)
$f$;

create function ct.res(p_key text) returns uuid
language sql security definer as $f$
  select id from public.reservations where idempotency_key = ct.id(p_key)
$f$;

create function ct.frz(p_pkg_key text) returns uuid
language sql security definer as $f$
  select id from public.package_freezes
  where member_package_id = ct.pkg(p_pkg_key)
  order by starts_at limit 1
$f$;

create function ct.wl(p_key text) returns bigint
language sql security definer as $f$
  select id from public.wallet_ledger where idempotency_key = ct.id(p_key)
$f$;

create function ct.sale(p_key text) returns uuid
language sql security definer as $f$
  select id from public.sales where idempotency_key = ct.id(p_key)
$f$;

-- Bu dosyaya özel yardımcılar (RLS'e takılmadan kimlik bulmak için; yalnızca test içinde)
create function ct.prog(p_title text) returns uuid
language sql security definer as $f$
  select id from public.workout_programs where title = p_title
  order by created_at desc limit 1
$f$;

create function ct.meas(p_note text) returns uuid
language sql security definer as $f$
  select id from public.body_measurements where note = p_note limit 1
$f$;

create function ct.prog_active(p_title text) returns boolean
language sql security definer as $f$
  select is_active from public.workout_programs where id = ct.prog(p_title)
$f$;

create function ct.item_count(p_title text) returns integer
language sql security definer as $f$
  select count(*)::int from public.workout_program_items where program_id = ct.prog(p_title)
$f$;

create function ct.sale_entry(p_key text) returns bigint
language sql security definer as $f$
  select id from public.wallet_ledger where sale_id = ct.sale(p_key)
    and entry_type = 'purchase' limit 1
$f$;

-- Rezervasyonu doğrudan ekler (book_class geçmiş derse izin vermez). Kontenjan sayacı
-- iptal edilmemiş kayıtlar için artırılır.
create function ct.make_res(
  p_class text, p_member text,
  p_status public.reservation_status default 'booked')
returns void language plpgsql as $f$
begin
  insert into public.reservations
    (class_id, member_id, member_package_id, status, idempotency_key, booked_by, cancelled_at)
  values
    (ct.id(p_class), ct.id(p_member), ct.pkg('k_pkg_' || p_member), p_status,
     ct.id('res_' || p_class || '_' || p_member), ct.id(p_member),
     case when p_status = 'cancelled' then now() end);
  if p_status <> 'cancelled' then
    update public.classes set booked_count = booked_count + 1 where id = ct.id(p_class);
  end if;
end
$f$;

-- Ocak 2020 raporu (çağıranın yetkisiyle çalışır)
create function ct.rep() returns jsonb
language sql stable as $f$
  select public.admin_report(date '2020-01-01', date '2020-01-31')
$f$;

-- ---------------------------------------------------------------------------
-- Hazırlık
--   Güncel dünya (eğitmenin üyesi kuralı):
--     trainer : ma (dün yapılan + yarınki ders). mb'nin trainer derslerindeki kayıtları
--               iptal; mc yalnızca 100 gün önceki derste; md pasif hesap.
--     trainer2: mb (gelecek ders), mc (3 gün önce gelmedi).
--   Rapor dünyası: Ocak 2020 (başka veriyle karışmasın diye geçmişte sabit bir ay).
-- ---------------------------------------------------------------------------
do $do$
begin
  perform ct.make_user('admin', 'admin');
  perform ct.make_user('trainer', 'trainer');
  perform ct.make_user('trainer2', 'trainer');
  perform ct.make_user('ma');
  perform ct.make_user('mb');
  perform ct.make_user('mc');
  perform ct.make_user('md');
end
$do$;

insert into public.categories (id, name) values (ct.id('cat_a'), 'pgTAP Kategori A');
insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price)
values (ct.id('def_a8'), ct.id('cat_a'), 'pgTAP A 8', 8, 30, 1000);
insert into public.products (id, name, price) values
  (ct.id('p30'), 'pgTAP Protein Bar', 30.00),
  (ct.id('p10'), 'pgTAP Su', 10.00);

-- Paket atamadan ÖNCE: "şu an aktif paketli üye" sayısının başlangıç değeri
select set_config('request.jwt.claims',
  json_build_object('sub', ct.id('admin'), 'role', 'authenticated')::text, true);
create table ct.base as
  select (public.admin_report(date '2020-01-01', date '2020-01-31')
            #>> '{members,active_with_package}')::int as active_with_package;
create function ct.base_active() returns integer
language sql security definer as $f$
  select active_with_package from ct.base
$f$;

do $do$
begin
  perform public.assign_package(ct.id('ma'), ct.id('def_a8'), ct.id('k_pkg_ma'));
  perform public.assign_package(ct.id('mb'), ct.id('def_a8'), ct.id('k_pkg_mb'));
  perform public.assign_package(ct.id('mc'), ct.id('def_a8'), ct.id('k_pkg_mc'));
  perform public.assign_package(ct.id('md'), ct.id('def_a8'), ct.id('k_pkg_md'));
  perform public.admin_wallet_topup(ct.id('ma'), 500, ct.id('k_top_ma'));
  perform public.admin_wallet_topup(ct.id('mb'), 200, ct.id('k_top_mb'));
  perform public.admin_wallet_topup(ct.id('ma'), 50, ct.id('k_top_rev'));
  perform public.admin_reverse_wallet_entry(ct.wl('k_top_rev'), ct.id('k_top_rev_r'), 'pgTAP');

  -- Güncel dersler
  perform ct.make_class('c_t1',    'trainer',  'cat_a', now() + interval '1 day');
  perform ct.make_class('c_t1b',   'trainer',  'cat_a', now() + interval '4 days');
  perform ct.make_class('c_cxl',   'trainer',  'cat_a', now() + interval '3 days');
  perform ct.make_class('c_past',  'trainer',  'cat_a', now() - interval '2 days');
  perform ct.make_class('c_old',   'trainer',  'cat_a', now() - interval '100 days');
  perform ct.make_class('c_t2',    'trainer2', 'cat_a', now() + interval '2 days');
  perform ct.make_class('c_past2', 'trainer2', 'cat_a', now() - interval '3 days');
  update public.classes set status = 'cancelled', cancelled_at = now()
  where id = ct.id('c_cxl');

  perform ct.make_res('c_t1',    'ma');
  perform ct.make_res('c_past',  'ma');
  perform ct.make_res('c_t1',    'md');
  perform ct.make_res('c_t1b',   'mb', 'cancelled');
  perform ct.make_res('c_cxl',   'mb', 'cancelled');
  perform ct.make_res('c_old',   'mc');
  perform ct.make_res('c_t2',    'mb');
  perform ct.make_res('c_past2', 'mc', 'no_show');
  update public.profiles set is_active = false where id = ct.id('md');

  -- Rapor dünyası: Ocak 2020 dersleri
  perform ct.make_class('r_c1', 'trainer',  'cat_a', timestamptz '2020-01-10 10:00+03');
  perform ct.make_class('r_c2', 'trainer',  'cat_a', timestamptz '2020-01-11 10:00+03', 'individual');
  perform ct.make_class('r_c3', 'trainer2', 'cat_a', timestamptz '2020-01-31 23:30+03');
  perform ct.make_class('r_cx', 'trainer2', 'cat_a', timestamptz '2020-01-13 10:00+03');
  perform ct.make_class('r_out', 'trainer', 'cat_a', timestamptz '2020-02-01 00:00+03');
  update public.classes set status = 'cancelled', cancelled_at = now()
  where id = ct.id('r_cx');
  perform ct.make_res('r_c1', 'ma');
  perform ct.make_res('r_c1', 'mb', 'no_show');
  perform ct.make_res('r_c2', 'ma');
  perform ct.make_res('r_c3', 'mb');
  perform ct.make_res('r_cx', 'mb', 'cancelled');
  perform ct.make_res('r_out', 'ma');
end
$do$;

-- Satışlar (eğitmen olarak), biri yönetici tarafından ters kayıtla iptal
select set_config('request.jwt.claims',
  json_build_object('sub', ct.id('trainer'), 'role', 'authenticated')::text, true);
do $do$
begin
  perform public.sell_product(ct.id('ma'), ct.id('p30'), 2, ct.id('k_s1'));
  perform public.sell_product(ct.id('mb'), ct.id('p30'), 1, ct.id('k_s2'));
  perform public.sell_product(ct.id('ma'), ct.id('p10'), 3, ct.id('k_s3'));
  perform public.sell_product(ct.id('ma'), ct.id('p30'), 1, ct.id('k_s4'));
end
$do$;
select set_config('request.jwt.claims',
  json_build_object('sub', ct.id('admin'), 'role', 'authenticated')::text, true);
do $do$
begin
  perform public.admin_reverse_wallet_entry(ct.sale_entry('k_s4'), ct.id('k_s4_r'), 'pgTAP');
end
$do$;
select set_config('request.jwt.claims', '', true);

-- Rapor verisini Ocak 2020'ye taşı. Sınırlar: ma'nın paketi aralığın ilk anında,
-- mb'ninki son saniyesinde, mc'ninki bitişten hemen sonra (aralık dışı).
update public.member_packages
  set activated_at = timestamptz '2020-01-01 00:00+03' where id = ct.pkg('k_pkg_ma');
update public.member_packages
  set activated_at = timestamptz '2020-01-31 23:59:59+03',
      discount_percent = 10, price_paid = 900 where id = ct.pkg('k_pkg_mb');
update public.member_packages
  set activated_at = timestamptz '2020-02-01 00:00+03' where id = ct.pkg('k_pkg_mc');
update public.wallet_ledger set created_at = timestamptz '2020-01-10 12:00+03'
  where idempotency_key in (ct.id('k_top_ma'), ct.id('k_top_mb'), ct.id('k_top_rev'));
update public.sales set created_at = timestamptz '2020-01-12 12:00+03'
  where idempotency_key in (ct.id('k_s1'), ct.id('k_s2'), ct.id('k_s3'), ct.id('k_s4'));
update public.profiles set created_at = timestamptz '2020-01-15 12:00+03'
  where id in (ct.id('ma'), ct.id('mb'), ct.id('trainer'));

-- ---------------------------------------------------------------------------
-- Y-10: eğitmenin üyeleri (trainer_my_members)
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select results_eq(
  $$select member_id, class_count, last_class_at, next_class_at
    from public.trainer_my_members()$$,
  $$select ct.id('ma'), 2, now() - interval '2 days', now() + interval '1 day'$$,
  'Y-10: eğitmen yalnızca kendi üyesini görür (iptal, 90 günden eski ve pasif hesap hariç)');
select is(
  (select full_name from public.trainer_my_members(ct.id('trainer'))),
  'Test ma', 'Y-10: eğitmen kendi kimliğiyle çağırabilir; ad döner');
select throws_ok(
  $$select * from public.trainer_my_members(ct.id('trainer2'))$$,
  '42501', 'FORBIDDEN', 'Y-10: eğitmen başka eğitmenin üyelerini listeleyemez');
select is(
  (select count(*)::int from public.profiles where id = ct.id('ma')),
  0, 'Y-05: eğitmen kendi üyesinin profilini (boy/kilo/doğum tarihi) yine göremez');
select is(
  (select count(*)::int from public.wallets where member_id = ct.id('ma')),
  0, 'Y-05: eğitmen kendi üyesinin cüzdanını yine göremez');
select is(
  (select count(*)::int from public.member_packages where member_id = ct.id('ma')),
  0, 'Y-05: eğitmen kendi üyesinin paketlerini yine göremez');

select ct.login('trainer2');
select results_eq(
  $$select member_id, class_count, last_class_at is null, next_class_at is null
    from public.trainer_my_members() order by full_name$$,
  $$values (ct.id('mb'), 1, true, false), (ct.id('mc'), 1, false, true)$$,
  'Y-10: gelecek dersi olan ve gelmedi işaretli üye de eğitmenin üyesidir');

select ct.login('admin');
select is(
  (select count(*)::int from public.trainer_my_members(ct.id('trainer'))),
  1, 'Y-10: yönetici bir eğitmenin üyelerini listeleyebilir');
select throws_ok(
  $$select * from public.trainer_my_members()$$,
  'P0001', 'TRAINER_REQUIRED', 'Y-10: yönetici eğitmen belirtmek zorundadır');

select ct.login('ma');
select throws_ok(
  $$select * from public.trainer_my_members()$$,
  '42501', 'FORBIDDEN', 'Y-10: üye trainer_my_members çağıramaz');

-- ---------------------------------------------------------------------------
-- A: antrenman programları
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select lives_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog A1', 'Kuvvet', 'Isınma şart',
      '[{"day_label":"Gün 1","exercise":"Squat","sets":3,"reps":"12","rest_seconds":60},
        {"day_label":"Gün 1","exercise":"Plank","reps":"30 sn","note":"3 tekrar"},
        {"day_label":"Gün 2","exercise":"Row","sets":"4","reps":"8-10"}]'::jsonb)$$,
  'A-01: eğitmen kendi üyesine program hazırlar');
select results_eq(
  $$select exercise, sets, reps, rest_seconds, sort_order
    from public.workout_program_items where program_id = ct.prog('Prog A1')
    order by sort_order$$,
  $$values ('Squat', 3, '12', 60, 1), ('Plank', null::int, '30 sn', null::int, 2),
           ('Row', 4, '8-10', null::int, 3)$$,
  'A-02: hareketler dizi sırasıyla kaydedilir');
select throws_ok(
  $$select public.save_workout_program(ct.id('mb'), 'Prog X', null, null, '[]'::jsonb)$$,
  '42501', 'FORBIDDEN', 'Y-10: eğitmen başka eğitmenin üyesine program yazamaz');
select throws_ok(
  $$select public.save_workout_program(ct.id('mc'), 'Prog X', null, null, '[]'::jsonb)$$,
  '42501', 'FORBIDDEN', 'Y-10: 90 günden eski ders üyeyi eğitmenin üyesi yapmaz');
select throws_ok(
  $$select public.save_workout_program(ct.id('md'), 'Prog X', null, null, '[]'::jsonb)$$,
  '42501', 'FORBIDDEN', 'Y-10: pasif üyeye program yazılamaz');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), '   ', null, null, '[]'::jsonb)$$,
  'P0001', 'INVALID_INPUT', 'A-01: başlık zorunludur');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog X', null, null,
      '[{"day_label":"Gün 1","exercise":" "}]'::jsonb)$$,
  'P0001', 'INVALID_INPUT', 'A-02: hareket adı zorunludur');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog X', null, null,
      '[{"day_label":"Gün 1","exercise":"Squat","sets":"çok"}]'::jsonb)$$,
  'P0001', 'INVALID_INPUT', 'A-02: set sayısı sayı olmalıdır');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog X', null, null,
      '{"day_label":"Gün 1"}'::jsonb)$$,
  'P0001', 'INVALID_INPUT', 'A-02: hareketler dizi olmalıdır');

select lives_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog A2', null, null,
      '[{"day_label":"Pazartesi","exercise":"Deadlift","sets":5,"reps":"5"}]'::jsonb)$$,
  'A-03: ikinci aktif program kaydedilir');
select is(ct.prog_active('Prog A1'), false, 'A-03: önceki aktif program pasife alınır');
select is(ct.prog_active('Prog A2'), true, 'A-03: yeni program aktiftir');

-- Düzenleme: hareketler değiştirilir; hatalı düzenleme hiçbir şeyi değiştirmez
select lives_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog A1', 'Yeni hedef', null,
      '[{"day_label":"Gün 1","exercise":"Lunge","sets":3,"reps":"10"}]'::jsonb,
      ct.prog('Prog A1'), false)$$,
  'A-04: eğitmen programı düzenler');
select is(ct.item_count('Prog A1'), 1, 'A-04: düzenlemede hareketler yenileriyle değişir');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog A1', null, null,
      '[{"day_label":"Gün 1","exercise":"Lunge","sets":500}]'::jsonb,
      ct.prog('Prog A1'), false)$$,
  'P0001', 'INVALID_INPUT', 'A-02: set sayısı 1-99 olmalıdır');
select is(ct.item_count('Prog A1'), 1, 'A-04: hatalı düzenleme eski hareketleri silmez');

select lives_ok(
  $$select public.set_workout_program_active(ct.prog('Prog A1'), true)$$,
  'A-05: eğitmen eski programı yeniden aktif yapar');
select is(ct.prog_active('Prog A2'), false, 'A-05: aktif yapılınca diğeri pasife düşer');
select is(
  (select count(*)::int from public.workout_programs
   where member_id = ct.id('ma') and is_active),
  1, 'A-03: üyenin tek aktif programı vardır');

reset role;
select throws_ok(
  $$insert into public.workout_programs (member_id, title, is_active)
    values (ct.id('ma'), 'Prog çift', true)$$,
  '23505', NULL, 'A-03: ikinci aktif program veritabanı kısıtıyla reddedilir');
select is(
  (select count(*)::int from public.audit_log
   where actor_id = ct.id('trainer') and entity = 'workout_programs'),
  4, 'Y-09: eğitmenin program işlemleri denetim kaydına yazılır');

select ct.login('admin');
select lives_ok(
  $$select public.save_workout_program(ct.id('mb'), 'Prog B1', null, null,
      '[{"day_label":"Gün 1","exercise":"Bench","sets":3,"reps":"8"}]'::jsonb)$$,
  'Y-06: yönetici herhangi bir üyeye program hazırlar');
select throws_ok(
  $$select public.save_workout_program(ct.id('trainer'), 'Prog X', null, null, '[]'::jsonb)$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'A-01: program yalnızca üyeye hazırlanır');
select is(
  (select count(*)::int from public.workout_programs
   where member_id in (ct.id('ma'), ct.id('mb'))),
  3, 'Y-06: yönetici tüm programları görür');

select ct.login('trainer');
select is(
  (select count(*)::int from public.workout_programs where member_id = ct.id('ma')),
  2, 'Y-10: eğitmen kendi üyesinin programlarını görür');
select is(
  (select count(*)::int from public.workout_programs where member_id = ct.id('mb')),
  0, 'Y-10: eğitmen başka üyenin programını göremez');
select is(
  (select count(*)::int from public.workout_program_items
   where program_id = ct.prog('Prog B1')),
  0, 'Y-10: eğitmen başka üyenin program hareketlerini göremez');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog X', null, null, '[]'::jsonb,
      ct.prog('Prog B1'))$$,
  'P0002', 'PROGRAM_NOT_FOUND', 'Y-10: başka üyenin programı kendi üyesi üzerinden düzenlenemez');
select throws_ok(
  $$select public.set_workout_program_active(ct.prog('Prog B1'), false)$$,
  'P0002', 'PROGRAM_NOT_FOUND', 'Y-10: eğitmen başka üyenin programını pasife alamaz');
select throws_ok(
  $$update public.workout_programs set title = 'x' where id = ct.prog('Prog A1')$$,
  '42501', NULL, 'A: eğitmen tabloya doğrudan yazamaz (yalnızca RPC)');

select ct.login('trainer2');
select is(
  (select count(*)::int from public.workout_programs where member_id = ct.id('mb')),
  1, 'Y-10: eğitmen, yöneticinin kendi üyesine hazırladığı programı görür');

select ct.login('ma');
select is(
  (select count(*)::int from public.workout_programs),
  2, 'Y-04: üye yalnızca kendi programlarını görür');
select is(
  (select count(*)::int from public.workout_program_items),
  2, 'Y-04: üye yalnızca kendi program hareketlerini görür');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'Prog X', null, null, '[]'::jsonb)$$,
  '42501', 'FORBIDDEN', 'Y-04: üye kendine program yazamaz');
select throws_ok(
  $$select public.set_workout_program_active(ct.prog('Prog A2'), true)$$,
  '42501', 'FORBIDDEN', 'Y-04: üye program durumunu değiştiremez');
select throws_ok(
  $$insert into public.workout_programs (member_id, title) values (ct.id('ma'), 'x')$$,
  '42501', NULL, 'Y-04: üye tabloya doğrudan program ekleyemez');
select throws_ok(
  $$delete from public.workout_program_items$$,
  '42501', NULL, 'Y-04: üye program hareketlerini silemez');

-- ---------------------------------------------------------------------------
-- O: vücut ölçümleri
-- ---------------------------------------------------------------------------
select is(
  (select weight_kg from public.add_body_measurement(
     ct.id('ma'), null, 70.04, null, null, 80, null, null, null, null, 'm_ma_own')),
  70.0, 'O-02: üye kendi ölçümünü ekler; değer tek ondalığa yuvarlanır');
select is(
  (select measured_on from public.body_measurements where id = ct.meas('m_ma_own')),
  ct.today(), 'O-03: tarih verilmezse bugün (İstanbul) yazılır');
select throws_ok(
  $$select public.add_body_measurement(ct.id('mb'), null, 60)$$,
  '42501', 'FORBIDDEN', 'Y-04: üye başka üyeye ölçüm ekleyemez');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today() + 1, 70)$$,
  'P0001', 'INVALID_DATE', 'O-03: ölçüm tarihi gelecekte olamaz');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today(), p_note => 'boş')$$,
  'P0001', 'MEASUREMENT_EMPTY', 'O-01: en az bir ölçü girilmelidir');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today(), 5)$$,
  '23514', NULL, 'O-01: aralık dışı kilo reddedilir');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today(), p_body_fat_pct => 90)$$,
  '23514', NULL, 'O-01: aralık dışı yağ oranı reddedilir');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today(), 1000000)$$,
  'P0001', 'INVALID_INPUT', 'O-01: taşan sayı INVALID_INPUT döner');
select throws_ok(
  $$insert into public.body_measurements (member_id, measured_on, weight_kg)
    values (ct.id('ma'), ct.today(), 70)$$,
  '42501', NULL, 'Y-04: üye tabloya doğrudan ölçüm ekleyemez');

select ct.login('trainer');
select lives_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today() - 7, 71.5,
      p_note => 'm_ma_tr')$$,
  'Y-10: eğitmen kendi üyesine ölçüm ekler');
select throws_ok(
  $$select public.add_body_measurement(ct.id('mb'), ct.today(), 60)$$,
  '42501', 'FORBIDDEN', 'Y-10: eğitmen başka üyeye ölçüm ekleyemez');
select throws_ok(
  $$select public.add_body_measurement(ct.id('trainer'), ct.today(), 80)$$,
  '42501', 'FORBIDDEN', 'O-02: eğitmen kendine ölçüm ekleyemez (yalnızca üyeler)');
select is(
  (select count(*)::int from public.body_measurements where member_id = ct.id('ma')),
  2, 'Y-10: eğitmen kendi üyesinin ölçümlerini görür');

select ct.login('trainer2');
select lives_ok(
  $$select public.add_body_measurement(ct.id('mb'), ct.today(), 60, p_note => 'm_mb_tr2')$$,
  'Y-10: ikinci eğitmen kendi üyesine ölçüm ekler');
select is(
  (select count(*)::int from public.body_measurements where member_id = ct.id('ma')),
  0, 'Y-10: eğitmen başka üyenin ölçümlerini göremez');

select ct.login('admin');
select lives_ok(
  $$select public.add_body_measurement(ct.id('mc'), ct.today(), p_waist_cm => 90,
      p_note => 'm_mc_ad')$$,
  'Y-06: yönetici herhangi bir üyeye ölçüm ekler');
select throws_ok(
  $$select public.add_body_measurement(ct.id('trainer'), ct.today(), 80)$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'O-02: ölçüm yalnızca üyeye eklenir');
select is(
  (select count(*)::int from public.body_measurements
   where member_id in (ct.id('ma'), ct.id('mb'), ct.id('mc'))),
  4, 'Y-06: yönetici tüm ölçümleri görür');

reset role;
select throws_ok(
  $$insert into public.body_measurements (member_id, measured_on, note)
    values (ct.id('ma'), ct.today(), 'boş')$$,
  '23514', NULL, 'O-01: ölçüsüz kayıt veritabanı kısıtıyla reddedilir');
select is(
  (select count(*)::int from public.audit_log
   where entity = 'body_measurements' and action = 'body_measurement_add'
     and actor_id in (ct.id('trainer'), ct.id('trainer2'), ct.id('admin'))),
  3, 'Y-09: eğitmen/yönetici ölçüm eklemeleri denetim kaydına yazılır');
select is(
  (select count(*)::int from public.audit_log
   where entity = 'body_measurements'
     and (actor_id = ct.id('ma') or details ? 'weight_kg')),
  0, 'O-06: üyenin kendi ölçümü ve ölçüm değerleri denetim kaydına yazılmaz');

select ct.login('mb');
select is(
  (select count(*)::int from public.body_measurements),
  1, 'Y-04: üye yalnızca kendi ölçümlerini görür');
select throws_ok(
  $$select public.delete_body_measurement(ct.meas('m_mb_tr2'))$$,
  'P0002', 'MEASUREMENT_NOT_FOUND', 'O-05: üye eğitmenin girdiği ölçümü silemez');
select throws_ok(
  $$select public.delete_body_measurement(ct.meas('m_ma_own'))$$,
  'P0002', 'MEASUREMENT_NOT_FOUND', 'Y-04: üye başkasının ölçümünü silemez');

select ct.login('ma');
select is(
  (select count(*)::int from public.body_measurements),
  2, 'Y-04: üye kendi ve eğitmeninin girdiği kendi ölçümlerini görür');
select lives_ok(
  $$select public.delete_body_measurement(ct.meas('m_ma_own'))$$,
  'O-05: üye kendi girdiği ölçümü siler');

select ct.login('trainer');
select throws_ok(
  $$select public.delete_body_measurement(ct.meas('m_mb_tr2'))$$,
  'P0002', 'MEASUREMENT_NOT_FOUND', 'Y-10: eğitmen başka üyenin ölçümünü silemez');
select lives_ok(
  $$select public.delete_body_measurement(ct.meas('m_ma_tr'))$$,
  'O-05: eğitmen kendi girdiği ölçümü siler');

select ct.login('admin');
select lives_ok(
  $$select public.delete_body_measurement(ct.meas('m_mb_tr2'))$$,
  'O-05: yönetici her ölçümü silebilir');
select is(
  (select count(*)::int from public.body_measurements
   where member_id in (ct.id('ma'), ct.id('mb'), ct.id('mc'))),
  1, 'O-05: silinen ölçümler kalkar');

-- Üye-eğitmen bağı kopunca erişim de biter
reset role;
update public.reservations set status = 'cancelled', cancelled_at = now()
where member_id = ct.id('ma') and class_id in (ct.id('c_t1'), ct.id('c_past'));
select ct.login('trainer');
select is(
  (select count(*)::int from public.workout_programs where member_id = ct.id('ma')),
  0, 'Y-10: rezervasyon bağı kalmayınca eğitmen programları göremez');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), ct.today(), 70)$$,
  '42501', 'FORBIDDEN', 'Y-10: rezervasyon bağı kalmayınca eğitmen ölçüm ekleyemez');

-- ---------------------------------------------------------------------------
-- RP: yönetici raporu (Ocak 2020)
-- ---------------------------------------------------------------------------
select throws_ok(
  $$select public.admin_report(date '2020-01-01', date '2020-01-31')$$,
  '42501', 'FORBIDDEN', 'RP-01: eğitmen rapor alamaz');
select ct.login('ma');
select throws_ok(
  $$select public.admin_report(date '2020-01-01', date '2020-01-31')$$,
  '42501', 'FORBIDDEN', 'RP-01: üye rapor alamaz');

select ct.login('admin');
select throws_ok(
  $$select public.admin_report(date '2020-02-01', date '2020-01-31')$$,
  'P0001', 'INVALID_DATE_RANGE', 'RP-02: bitiş başlangıçtan önce olamaz');
select throws_ok(
  $$select public.admin_report(date '2020-01-01', date '2021-06-01')$$,
  'P0001', 'INVALID_DATE_RANGE', 'RP-02: aralık en fazla 366 gündür');
select is(
  (public.admin_report() ->> 'from')::date,
  date_trunc('month', ct.today()::timestamp)::date,
  'RP-02: parametresiz çağrı içinde bulunulan ayı (İstanbul) kullanır');
select is(
  (public.admin_report() ->> 'to')::date,
  (date_trunc('month', ct.today()::timestamp) + interval '1 month - 1 day')::date,
  'RP-02: parametresiz çağrı ayın son gününde biter');

select is(ct.rep() -> 'package_sales',
  '{"count":2,"total":1900.00,"list_total":2000.00,"discount_total":100.00,"discounted_count":1}'::jsonb,
  'RP-03: paket satışı adedi, tahsilat ve indirim (aralık uçları dahil, sonrası hariç)');
select is(ct.rep() -> 'product_sales',
  '{"count":3,"quantity":6,"total":120.00,"reversed_count":1}'::jsonb,
  'RP-04: ürün satışı ters kaydı alınanlar hariç');
select is(ct.rep() -> 'wallet_topups',
  '{"count":2,"total":700.00}'::jsonb,
  'RP-05: cüzdan yüklemesi ters kaydı alınanlar hariç');
select is((ct.rep() #>> '{members,new}')::int, 2,
  'RP-06: yeni üye sayısı (eğitmen hesabı sayılmaz)');
select is((ct.rep() #>> '{members,active_with_package}')::int - ct.base_active(), 3,
  'RP-06: şu an aktif paketli üye sayısı (pasif hesap sayılmaz)');
select is(ct.rep() -> 'classes',
  '{"held":3,"upcoming":0,"cancelled":1,"capacity":13,"booked":4,"occupancy_pct":30.8}'::jsonb,
  'RP-07: yapılan/iptal edilen ders ve ortalama doluluk');
select is(ct.rep() -> 'attendance',
  '{"attended":3,"no_show":1}'::jsonb,
  'RP-08: katılan ve gelmeyen sayısı');
select is(ct.rep() -> 'trainers',
  jsonb_build_array(
    jsonb_build_object('trainer_id', ct.id('trainer'), 'full_name', 'Test trainer',
      'class_count', 2, 'capacity', 7, 'booked', 3, 'attended', 2, 'no_show', 1),
    jsonb_build_object('trainer_id', ct.id('trainer2'), 'full_name', 'Test trainer2',
      'class_count', 1, 'capacity', 6, 'booked', 1, 'attended', 1, 'no_show', 0)),
  'RP-09: eğitmen bazında ders ve katılım');
select is(ct.rep() -> 'top_products',
  jsonb_build_array(
    jsonb_build_object('product_id', ct.id('p30'), 'name', 'pgTAP Protein Bar',
      'quantity', 3, 'total', 90.00),
    jsonb_build_object('product_id', ct.id('p10'), 'name', 'pgTAP Su',
      'quantity', 3, 'total', 30.00)),
  'RP-10: en çok satan ürünler (adet, sonra tutar sırasıyla)');
select is(
  (public.admin_report(date '2020-02-01', date '2020-02-01') #>> '{package_sales,count}')::int,
  1, 'RP-03: aralık bitişinden sonraki gün başlayan paket ertesi günün raporundadır');

-- ---------------------------------------------------------------------------
-- Y-08: giriş yapmamış istemci (anon)
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select count(*) from public.workout_programs$$,
  '42501', NULL, 'Y-08: anon programları okuyamaz');
select throws_ok(
  $$select count(*) from public.workout_program_items$$,
  '42501', NULL, 'Y-08: anon program hareketlerini okuyamaz');
select throws_ok(
  $$select count(*) from public.body_measurements$$,
  '42501', NULL, 'Y-08: anon ölçümleri okuyamaz');
select throws_ok(
  $$select * from public.trainer_my_members()$$,
  '42501', NULL, 'Y-08: anon trainer_my_members çağıramaz');
select throws_ok(
  $$select public.save_workout_program(ct.id('ma'), 'x', null, null, '[]'::jsonb)$$,
  '42501', NULL, 'Y-08: anon save_workout_program çağıramaz');
select throws_ok(
  $$select public.add_body_measurement(ct.id('ma'), null, 70)$$,
  '42501', NULL, 'Y-08: anon add_body_measurement çağıramaz');
select throws_ok(
  $$select public.admin_report()$$,
  '42501', NULL, 'Y-08: anon admin_report çağıramaz');
reset role;

select * from finish();
rollback;
