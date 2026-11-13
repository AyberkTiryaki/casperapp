-- Casper Training Studio — pgTAP: Paketler: atama, tek aktif paket, yenileme ve aktarım, indirim
-- Kurallar: P-01..P-11, F-06, F-10, F-11, F-16 (docs/BUSINESS_RULES.md)
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(69);

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
-- onayını oluşturur. Rol, postgres olarak doğrudan güncellenir (ilk yönetici gibi).
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
                        'kvkk_accepted', 'true', 'kvkk_version', 'pgtap-1'),
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

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------
do $do$
begin
  perform ct.make_user('admin', 'admin');
  perform ct.make_user('trainer', 'trainer');
  perform ct.make_user('m' || g) from generate_series(1, 8) g;
end
$do$;

insert into public.categories (id, name) values
  (ct.id('cat_a'), 'pgTAP Kategori A'),
  (ct.id('cat_b'), 'pgTAP Kategori B');

insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price, is_active)
values
  (ct.id('def_a8'),  ct.id('cat_a'), 'pgTAP A 8',    8, 30, 1000, true),
  (ct.id('def_a16'), ct.id('cat_a'), 'pgTAP A 16',  16, 40, 1800, true),
  (ct.id('def_b12'), ct.id('cat_b'), 'pgTAP B 12',  12, 30, 1500, true),
  (ct.id('def_off'), ct.id('cat_a'), 'pgTAP pasif',  8, 30, 1000, false);

do $do$
begin
  -- m2: 3 gelecek ders + 1 (sonradan geçmişe alınacak) ders
  perform ct.make_class('c_m2_' || g, 'trainer', 'cat_a', now() + make_interval(days => g))
  from generate_series(1, 3) g;
  perform ct.make_class('c_m2_past', 'trainer', 'cat_a', now() + interval '1 hour');
  -- m3: biri yeni paketin süresi içinde, biri dışında
  perform ct.make_class('c_m3_in',  'trainer', 'cat_a', now() + interval '10 days');
  perform ct.make_class('c_m3_out', 'trainer', 'cat_a', now() + interval '35 days');
  -- m4: 9 ders (yeni 8 derslik pakete sığmaz)
  perform ct.make_class('c_m4_' || g, 'trainer', 'cat_a',
                        now() + make_interval(days => g, hours => 3))
  from generate_series(1, 9) g;
end
$do$;

-- ---------------------------------------------------------------------------
-- P-03: paketi yalnızca yönetici atar
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_yetkisiz_1'))$$,
  '42501', 'FORBIDDEN', 'P-03/Y-05: eğitmen paket atayamaz');

select ct.login('m1');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_yetkisiz_2'))$$,
  '42501', 'FORBIDDEN', 'P-03: üye kendine paket atayamaz');

-- ---------------------------------------------------------------------------
-- P-02, P-03, P-06: atama, süre, fiyat kopyası
-- ---------------------------------------------------------------------------
select ct.login('admin');
select is(
  (select status::text
   from public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_m1_a8'))),
  'active', 'P-03: paket atandığı anda aktif olur');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_m1_a8')),
  8, 'P-01: kalan hak = ders sayısı');
select is(
  (select total_credits from public.member_packages where id = ct.pkg('k_m1_a8')),
  8, 'P-01: toplam hak = ders sayısı');
select ok(
  (select activated_at = now() and ends_at = activated_at + interval '30 days'
   from public.member_packages where id = ct.pkg('k_m1_a8')),
  'P-02: 8 derslik paket aktivasyondan itibaren 30 gün geçerli');
select is(
  (select price_paid from public.member_packages where id = ct.pkg('k_m1_a8')),
  1000.00::numeric, 'P-06: atama anındaki fiyat pakete kopyalanır');
select is(
  (select count(*)::int from public.credit_ledger
   where member_package_id = ct.pkg('k_m1_a8')
     and entry_type = 'grant' and delta = 8 and balance_after = 8),
  1, 'Atamada tek grant hareketi yazılır');
select is(
  (select count(*)::int from public.audit_log
   where action = 'assign_package' and entity_id = ct.pkg('k_m1_a8')::text
     and actor_id = ct.id('admin')),
  1, 'Y-09: paket atama denetim kaydına yazılır');

-- ---------------------------------------------------------------------------
-- P-11: tekrarlanan istek ikinci paket yaratmaz
-- ---------------------------------------------------------------------------
select ct.login('admin');
select is(
  (select id from public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_m1_a8'))),
  ct.pkg('k_m1_a8'), 'P-11: aynı anahtar aynı paketi döndürür');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_b12'), ct.id('k_m1_a8'))$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'P-11: aynı anahtar başka tanım için kullanılamaz');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), null)$$,
  'P0001', 'IDEMPOTENCY_KEY_REQUIRED', 'Anahtarsız atama reddedilir');

-- ---------------------------------------------------------------------------
-- P-05, P-07: aynı kategoride tek aktif paket
-- ---------------------------------------------------------------------------
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_m1_a8_ikinci'))$$,
  'P0001', 'ACTIVE_PACKAGE_EXISTS', 'P-07: aktif paket varken aynı kategoride atama yapılamaz');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a16'), ct.id('k_m1_a16'))$$,
  'P0001', 'ACTIVE_PACKAGE_EXISTS', 'P-05: aynı kategorinin başka tanımı da atanamaz');
select lives_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_b12'), ct.id('k_m1_b12'))$$,
  'P-05: farklı kategoride ikinci aktif paket olabilir');
select throws_ok(
  $$select public.assign_package(ct.id('trainer'), ct.id('def_a8'), ct.id('k_egitmene'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'Paket yalnızca üye rolüne atanır');
select throws_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_off'), ct.id('k_pasif_tanim'))$$,
  'P0002', 'DEFINITION_NOT_FOUND', 'Pasif paket tanımı atanamaz');

reset role;
select is(
  (select count(*)::int from public.member_packages where member_id = ct.id('m1')),
  2, 'P-11: başarısız ve tekrarlanan istekler paket yaratmadı (toplam 2)');
select is(
  (select count(*)::int from public.member_packages
   where member_id = ct.id('m1') and status = 'active'),
  2, 'P-05: iki farklı kategoride iki aktif paket');

-- ---------------------------------------------------------------------------
-- P-07, P-08: yenileme — 3 gelecek rezervasyon yeni pakete aktarılır
-- ---------------------------------------------------------------------------
select ct.login('admin');
select is(
  (select ends_at - activated_at
   from public.assign_package(ct.id('m2'), ct.id('def_a16'), ct.id('k_m2_eski'))),
  interval '40 days', 'P-02: 16 derslik paket 40 gün geçerli');

select ct.login('m2');
select is(
  (select count(r.id)::int
   from generate_series(1, 3) g,
        lateral public.book_class(ct.id('c_m2_' || g), ct.id('k_m2_rez_' || g)) r),
  3, 'Hazırlık: m2 üç gelecek derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_m2_past'), ct.id('k_m2_rez_past'))$$,
  'Hazırlık: m2 dördüncü derse rezervasyon yaptı');

reset role;
-- Dördüncü ders artık başlamış (geçmiş) olsun
update public.classes
set starts_at = now() - interval '2 hours', ends_at = now() - interval '1 hour'
where id = ct.id('c_m2_past');

select ct.login('admin');
select is(
  (select remaining_credits
   from public.assign_package(ct.id('m2'), ct.id('def_a8'), ct.id('k_m2_yeni'), true)),
  5, 'P-08: yeni paketin hakkı aktarılan 3 rezervasyon kadar azalır (8 - 3)');

reset role;
select is(
  (select status::text from public.member_packages where id = ct.pkg('k_m2_eski')),
  'terminated', 'P-07: yenilemede eski paket erken bitirilir');
select ok(
  (select closed_at is not null and replaced_by = ct.pkg('k_m2_yeni')
   from public.member_packages where id = ct.pkg('k_m2_eski')),
  'P-07: eski paket kapanış zamanı ve yerine geçen paketle işaretlenir');
select is(
  (select count(*)::int from public.member_packages
   where member_id = ct.id('m2') and category_id = ct.id('cat_a') and status = 'active'),
  1, 'P-05: yenilemeden sonra kategoride tek aktif paket var');
select is(
  (select count(*)::int from public.reservations
   where member_id = ct.id('m2') and status = 'booked'
     and member_package_id = ct.pkg('k_m2_yeni')),
  3, 'P-08: üç gelecek rezervasyon yeni pakete bağlandı');
select is(
  (select member_package_id from public.reservations where id = ct.res('k_m2_rez_past')),
  ct.pkg('k_m2_eski'), 'P-08: başlamış dersin rezervasyonu eski pakette kalır');
select is(
  (select count(*)::int from public.reservations
   where member_id = ct.id('m2') and status = 'cancelled'),
  0, 'P-08: aktarılabilen rezervasyonlar iptal edilmez');
select is(
  (select count(*)::int from public.credit_ledger
   where member_package_id = ct.pkg('k_m2_eski')
     and entry_type = 'transfer_out' and delta = 1),
  3, 'P-08: eski pakete 3 transfer_out (+1) hareketi');
select is(
  (select count(*)::int from public.credit_ledger
   where member_package_id = ct.pkg('k_m2_yeni')
     and entry_type = 'transfer_in' and delta = -1),
  3, 'P-08: yeni paketten 3 transfer_in (-1) hareketi');
select is(
  (select min(balance_after) from public.credit_ledger
   where member_package_id = ct.pkg('k_m2_yeni') and entry_type = 'transfer_in'),
  5, 'P-08: son aktarım hareketinin bakiyesi 5');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_m2_eski')),
  15, 'P-10: eski paketin hakkı kayıt amaçlı kalır (16 - 4 + 3), paket kapalıdır');
select is(
  (select sum(booked_count)::int from public.classes
   where id in (ct.id('c_m2_1'), ct.id('c_m2_2'), ct.id('c_m2_3'))),
  3, 'P-08: aktarım derslerin dolu kontenjanını değiştirmez');

select ct.login('m2');
select throws_ok(
  $$select public.assign_package(ct.id('m2'), ct.id('def_a8'), ct.id('k_m2_yeni'), true)$$,
  '42501', 'FORBIDDEN', 'P-07: üye yenileme yapamaz');

-- ---------------------------------------------------------------------------
-- P-09: yeni paketin bitişinden sonraki ders aktarılmaz; iptal + eski pakete iade
-- ---------------------------------------------------------------------------
select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m3'), ct.id('def_a16'), ct.id('k_m3_eski'))$$,
  'Hazırlık: m3 40 günlük paket aldı');

select ct.login('m3');
select lives_ok(
  $$select public.book_class(ct.id('c_m3_in'), ct.id('k_m3_rez_in'))$$,
  'Hazırlık: m3 10 gün sonraki derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_m3_out'), ct.id('k_m3_rez_out'))$$,
  'Hazırlık: m3 35 gün sonraki derse rezervasyon yaptı');

select ct.login('admin');
select is(
  (select remaining_credits
   from public.assign_package(ct.id('m3'), ct.id('def_a8'), ct.id('k_m3_yeni'), true)),
  7, 'P-08/P-09: yalnızca geçerlilik içindeki 1 rezervasyon aktarıldı (8 - 1)');

reset role;
select is(
  (select member_package_id from public.reservations where id = ct.res('k_m3_rez_in')),
  ct.pkg('k_m3_yeni'), 'P-08: süre içindeki rezervasyon yeni pakete aktarıldı');
select is(
  (select status::text from public.reservations where id = ct.res('k_m3_rez_out')),
  'cancelled', 'P-09: yeni paket bitişinden sonraki rezervasyon iptal edildi');
select ok(
  (select credit_refunded and member_package_id = ct.pkg('k_m3_eski')
          and cancelled_by = ct.id('admin')
   from public.reservations where id = ct.res('k_m3_rez_out')),
  'P-09: iptal edilen rezervasyon eski pakette kalır ve iade işaretlidir');
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_m3_rez_out') and entry_type = 'refund'
     and delta = 1 and member_package_id = ct.pkg('k_m3_eski')),
  1, 'P-09: iade eski paketin hareketlerine yazıldı');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_m3_eski')),
  16, 'P-09: eski paket hakkı 16 - 2 + 1 (aktarım) + 1 (iade) = 16');
select is(
  (select booked_count from public.classes where id = ct.id('c_m3_out')),
  0, 'P-09/I-05: iptal edilen rezervasyonun yeri açıldı');

-- ---------------------------------------------------------------------------
-- P-08/P-09: yeni pakette hak bitince kalan rezervasyon iptal edilir
-- ---------------------------------------------------------------------------
select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m4'), ct.id('def_a16'), ct.id('k_m4_eski'))$$,
  'Hazırlık: m4 16 derslik paket aldı');

select ct.login('m4');
select is(
  (select count(r.id)::int
   from generate_series(1, 9) g,
        lateral public.book_class(ct.id('c_m4_' || g), ct.id('k_m4_rez_' || g)) r),
  9, 'Hazırlık: m4 dokuz derse rezervasyon yaptı');

select ct.login('admin');
select is(
  (select remaining_credits
   from public.assign_package(ct.id('m4'), ct.id('def_a8'), ct.id('k_m4_yeni'), true)),
  0, 'P-08: 8 derslik yeni paketin tüm hakkı aktarımla doldu');

reset role;
select is(
  (select count(*)::int from public.reservations
   where member_id = ct.id('m4') and status = 'booked'
     and member_package_id = ct.pkg('k_m4_yeni')),
  8, 'P-08: ders tarihi sırasıyla ilk 8 rezervasyon aktarıldı');
select is(
  (select status::text from public.reservations where id = ct.res('k_m4_rez_9')),
  'cancelled', 'P-09: hak kalmadığı için en son tarihli rezervasyon iptal edildi');
select is(
  (select count(*)::int from public.reservations
   where member_id = ct.id('m4') and status = 'cancelled'),
  1, 'P-09: yalnızca bir rezervasyon iptal edildi');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_m4_eski')),
  16, 'P-09: eski paket hakkı 16 - 9 + 8 (aktarım) + 1 (iade) = 16');

-- ---------------------------------------------------------------------------
-- P-07: süresi dolmuş eski paket yeni atamada otomatik expired olur
-- ---------------------------------------------------------------------------
select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m5'), ct.id('def_a8'), ct.id('k_m5_eski'))$$,
  'Hazırlık: m5 paket aldı');

reset role;
update public.member_packages
set activated_at = now() - interval '31 days', ends_at = now() - interval '1 day'
where id = ct.pkg('k_m5_eski');

select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m5'), ct.id('def_a8'), ct.id('k_m5_yeni'))$$,
  'P-07: süresi dolmuş paket varken yenileme seçmeden yeni paket atanabilir');

reset role;
select is(
  (select status::text from public.member_packages where id = ct.pkg('k_m5_eski')),
  'expired', 'P-07: süresi dolmuş eski paket expired yapıldı');
select is(
  (select status::text from public.member_packages where id = ct.pkg('k_m5_yeni')),
  'active', 'P-07: yeni paket aktif');

-- Zamanlanmış görev (private.expire_packages) aynı işi atama olmadan yapar
select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m8'), ct.id('def_a8'), ct.id('k_m8'))$$,
  'Hazırlık: m8 paket aldı');

reset role;
update public.member_packages
set activated_at = now() - interval '31 days', ends_at = now() - interval '1 day'
where id = ct.pkg('k_m8');

select ok(
  (select private.expire_packages()) >= 1,
  'expire_packages süresi dolan aktif paketleri işler');
select ok(
  (select status = 'expired' and closed_at = ends_at
   from public.member_packages where id = ct.pkg('k_m8')),
  'expire_packages: durum expired, kapanış = bitiş anı');

-- ---------------------------------------------------------------------------
-- F-10, F-11: paket atamasında referans indirimi
-- ---------------------------------------------------------------------------
select ct.login('admin');
select throws_ok(
  $$select public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6_x1'), false, 51)$$,
  'P0001', 'INVALID_DISCOUNT', 'F-11: oran 50 üstü olamaz');
select throws_ok(
  $$select public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6_x2'), false, -1)$$,
  'P0001', 'INVALID_DISCOUNT', 'F-11: oran eksi olamaz');
select throws_ok(
  $$select public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6_x3'), false, 5)$$,
  'P0001', 'DISCOUNT_EXCEEDS_ENTITLEMENT', 'F-11: referansı olmayan üyeye indirim kaydedilemez');
select lives_ok(
  $$select public.admin_create_referral(ct.id('m6'), ct.id('m7'))$$,
  'F-16: yönetici elle onaylı referans ekler');
select throws_ok(
  $$select public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6_x4'), false, 5)$$,
  'P0001', 'DISCOUNT_EXCEEDS_ENTITLEMENT', 'F-06: getirilenin paketi yokken referans sayılmaz');
select lives_ok(
  $$select public.assign_package(ct.id('m7'), ct.id('def_a8'), ct.id('k_m7'))$$,
  'Hazırlık: getirilen üye paket aldı');
select throws_ok(
  $$select public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6_x5'), false, 10)$$,
  'P0001', 'DISCOUNT_EXCEEDS_ENTITLEMENT', 'F-11: hak edilen oran 5 iken 10 kaydedilemez');
select is(
  (select price_paid
   from public.assign_package(ct.id('m6'), ct.id('def_a8'), ct.id('k_m6'), false, 5)),
  950.00::numeric, 'F-10: indirimli fiyat = liste x (100 - oran) / 100');

reset role;
select ok(
  (select list_price = 1000 and discount_percent = 5
   from public.member_packages where id = ct.pkg('k_m6')),
  'F-10: liste fiyatı ve uygulanan oran saklanır');

-- ---------------------------------------------------------------------------
-- P-06: sonradan yapılan fiyat değişikliği atanmış paketleri etkilemez
-- ---------------------------------------------------------------------------
update public.package_definitions set price = 1250 where id = ct.id('def_a8');
select ok(
  (select price_paid = 1000 and list_price = 1000
   from public.member_packages where id = ct.pkg('k_m1_a8')),
  'P-06: fiyat değişikliği atanmış paketi etkilemez');

select * from finish();
rollback;
