-- Casper Training Studio — pgTAP: Yetki ve RLS: üye, eğitmen, yönetici, pasif hesap, anon
-- Kurallar: Y-02, Y-04..Y-08, K-06, K-07, F-13
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(113);

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
-- Hazırlık: ma'nın paketi, dondurması, rezervasyonları, cüzdan hareketleri ve
-- satışı vardır; mb / eğitmen / anon bunlara erişmeye çalışır.
-- ---------------------------------------------------------------------------
do $do$
begin
  perform ct.make_user('admin', 'admin');
  perform ct.make_user('trainer', 'trainer');
  perform ct.make_user('trainer2', 'trainer');
  perform ct.make_user('ma');
  perform ct.make_user('mb');
end
$do$;

insert into public.categories (id, name) values (ct.id('cat_a'), 'pgTAP Kategori A');

insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price)
values
  (ct.id('def_a8'), ct.id('cat_a'), 'pgTAP A 8', 8, 30, 1000);

insert into public.products (id, name, price) values
  (ct.id('p30'), 'pgTAP Protein Bar', 30.00);

do $do$
begin
  perform ct.make_class('c_t1', 'trainer',  'cat_a', now() + interval '1 day');
  perform ct.make_class('c_t2', 'trainer2', 'cat_a', now() + interval '2 days');
end
$do$;

-- K-06: kayıt verisindeki rol benzeri alanlar yok sayılır
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', ct.id('sahte_admin'), 'authenticated',
   'authenticated', 'pgtap-sahte-admin@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Sahte Yönetici","role":"admin","is_admin":true,"user_role":"admin"}'::jsonb,
   now(), now());

select is(
  (select role::text from public.profiles where id = ct.id('sahte_admin')),
  'member', 'K-06: kayıt verisindeki rol alanı yok sayılır, yeni hesap üyedir');

select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('ma'), ct.id('def_a8'), ct.id('k_pkg_ma'))$$,
  'Hazırlık: ma paket aldı');
select lives_ok(
  $$select public.assign_package(ct.id('mb'), ct.id('def_a8'), ct.id('k_pkg_mb'))$$,
  'Hazırlık: mb paket aldı');
select lives_ok(
  $$select public.admin_wallet_topup(ct.id('ma'), 100, ct.id('k_top_ma'))$$,
  'Hazırlık: ma cüzdanına 100 yüklendi');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_ma'), ct.today() + 20, ct.today() + 21)$$,
  'Hazırlık: ma paketi ileri tarihte donduruldu');
select lives_ok(
  $$select public.admin_create_referral(ct.id('mb'), ct.id('ma'))$$,
  'Hazırlık: mb, ma için referans oldu');

select ct.login('ma');
select lives_ok(
  $$select public.book_class(ct.id('c_t1'), ct.id('k_ma_t1'))$$,
  'Hazırlık: ma birinci eğitmenin dersine rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_t2'), ct.id('k_ma_t2'))$$,
  'Hazırlık: ma ikinci eğitmenin dersine rezervasyon yaptı');

select ct.login('trainer');
select lives_ok(
  $$select public.sell_product(ct.id('ma'), ct.id('p30'), 1, ct.id('k_sale_ma'))$$,
  'Hazırlık: eğitmen ma üyesine ürün sattı');

-- ---------------------------------------------------------------------------
-- Y-04: üye başka üyenin hiçbir verisini göremez
-- ---------------------------------------------------------------------------
select ct.login('mb');
select is(
  (select count(*)::int from public.member_packages where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin paketini göremez');
select is(
  (select count(*)::int from public.member_packages),
  1, 'Y-04/R-12: üye yalnızca kendi paketini görür');
select is(
  (select count(*)::int from public.wallets where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin cüzdanını göremez');
select is(
  (select count(*)::int from public.wallets),
  1, 'Y-04/C-02: üye yalnızca kendi cüzdanını görür');
select is(
  (select count(*)::int from public.wallet_ledger where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin cüzdan hareketlerini göremez');
select is(
  (select count(*)::int from public.reservations where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin rezervasyonlarını göremez');
select is(
  (select count(*)::int from public.credit_ledger where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin hak hareketlerini göremez');
select is(
  (select count(*)::int from public.sales where member_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin satışlarını göremez');
select is(
  (select count(*)::int from public.profiles where id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin profilini göremez');
select is(
  (select count(*)::int from public.profiles),
  1, 'Y-04: üye yalnızca kendi profilini görür');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin bildirimlerini göremez');
select is(
  (select count(*)::int from public.package_freezes),
  0, 'Y-04: üye başka üyenin dondurma kaydını göremez');
select is(
  (select count(*)::int from public.consents where user_id = ct.id('ma')),
  0, 'Y-04: üye başka üyenin KVKK onayını göremez');
select is(
  (select count(*)::int from public.audit_log),
  0, 'Y-04: üye denetim kayıtlarını göremez');
select is(
  (select count(*)::int from public.referrals),
  0, 'F-13: üye referans tablosunu doğrudan göremez');
select is(
  (select count(*)::int from public.class_participants(ct.id('c_t1'))),
  0, 'Y-04: üye katılımcı listesini göremez');
select is(
  (select count(*)::int from public.search_members('')),
  0, 'Y-04: üye, üye araması yapamaz');
select is(
  (select count(*)::int from public.admin_class_reservations(ct.id('c_t1'))),
  0, 'Y-04: üye yönetici rezervasyon listesini göremez');
select is(
  (select count(*)::int from public.admin_search_users('')),
  0, 'Y-04: üye kullanıcı araması yapamaz');
select is(
  (select count(*)::int from public.admin_list_referrals()),
  0, 'F-13: üye yönetici referans panelini göremez');
select is(
  (select count(*)::int from public.my_reservations()),
  0, 'R-12: my_reservations yalnızca çağıranın rezervasyonlarını döndürür');
select throws_ok(
  $$select public.referral_summary(ct.id('ma'))$$,
  '42501', 'FORBIDDEN', 'F-13: üye başkasının referans özetini göremez');
select is(
  (select count(*)::int from public.classes where id in (ct.id('c_t1'), ct.id('c_t2'))),
  2, 'S-05: giriş yapmış herkes ders takvimini görür');

-- Doğrudan yazma girişimleri
select throws_ok(
  $$update public.profiles set role = 'admin' where id = ct.id('mb')$$,
  '42501', NULL, 'Y-02/K-07: üye kendi rolünü değiştiremez');
select throws_ok(
  $$update public.profiles set is_active = false where id = ct.id('ma')$$,
  '42501', NULL, 'K-07: üye is_active alanını değiştiremez');
select lives_ok(
  $$update public.profiles set full_name = 'Ele Geçirildi' where id = ct.id('ma')$$,
  'Y-04: başkasının profilini güncelleme isteği hata vermez ama satıra ulaşamaz');
select lives_ok(
  $$update public.profiles set full_name = 'Yeni Ad', weight_kg = 70.5
    where id = ct.id('mb')$$,
  'K-07: üye kendi ad ve kilosunu güncelleyebilir');
select throws_ok(
  $$insert into public.member_packages (member_id) values (ct.id('mb'))$$,
  '42501', NULL, 'Y-04: üye doğrudan paket ekleyemez');
select throws_ok(
  $$update public.member_packages set remaining_credits = 99$$,
  '42501', NULL, 'Y-04: üye kalan hakkını doğrudan değiştiremez');
select throws_ok(
  $$update public.wallets set balance = 999999$$,
  '42501', NULL, 'Y-04: üye bakiyesini doğrudan değiştiremez');
select throws_ok(
  $$insert into public.wallet_ledger (member_id) values (ct.id('mb'))$$,
  '42501', NULL, 'Y-04: üye doğrudan cüzdan hareketi ekleyemez');
select throws_ok(
  $$update public.reservations set status = 'cancelled'$$,
  '42501', NULL, 'Y-04: üye rezervasyonu doğrudan değiştiremez');
select throws_ok(
  $$delete from public.credit_ledger$$,
  '42501', NULL, 'Y-04: üye hak hareketlerini silemez');
select throws_ok(
  $$insert into public.categories (name) values ('pgTAP izinsiz kategori')$$,
  '42501', NULL, 'Y-06: üye kategori ekleyemez');

-- Yönetici işlemleri
select throws_ok(
  $$select public.assign_package(ct.id('mb'), ct.id('def_a8'), ct.id('k_mb_x1'), true)$$,
  '42501', 'FORBIDDEN', 'Y-04: üye assign_package çağıramaz');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('mb'), 500, ct.id('k_mb_x2'))$$,
  '42501', 'FORBIDDEN', 'Y-04: üye admin_wallet_topup çağıramaz');
select throws_ok(
  $$select public.admin_set_role(ct.id('mb'), 'admin')$$,
  '42501', 'FORBIDDEN', 'Y-02: üye admin_set_role çağıramaz');
select throws_ok(
  $$select public.sell_product(ct.id('ma'), ct.id('p30'), 1, ct.id('k_mb_x3'))$$,
  '42501', 'FORBIDDEN', 'C-03: üye sell_product çağıramaz');

reset role;
select is(
  (select full_name from public.profiles where id = ct.id('ma')),
  'Test ma', 'Y-04: başkasının profili değişmedi');
select ok(
  (select full_name = 'Yeni Ad' and weight_kg = 70.5 and role = 'member'
   from public.profiles where id = ct.id('mb')),
  'K-07: üyenin kendi profil güncellemesi kaydedildi, rol değişmedi');

-- ---------------------------------------------------------------------------
-- R-12, C-02: üye kendi verisini görür
-- ---------------------------------------------------------------------------
select ct.login('ma');
select is(
  (select count(*)::int from public.member_packages),
  1, 'R-12: üye kendi paketini görür');
select is(
  (select count(*)::int from public.reservations),
  2, 'R-12: üye kendi rezervasyonlarını görür');
select is(
  (select count(*)::int from public.my_reservations()),
  2, 'R-12: my_reservations üyenin iki rezervasyonunu döndürür');
select is(
  (select count(*)::int from public.credit_ledger),
  3, 'R-12: üye kendi hak hareketlerini görür (grant + 2 booking)');
select is(
  (select count(*)::int from public.wallet_ledger),
  2, 'C-02: üye kendi cüzdan hareketlerini görür (yükleme + satış)');
select is(
  (select count(*)::int from public.sales),
  1, 'C-02: üye kendisine yapılan satışı görür');
select is(
  (select count(*)::int from public.package_freezes),
  1, 'Üye kendi paketinin dondurma kaydını görür');
select is(
  (select count(*)::int from public.notifications where kind = 'booking_confirmed'),
  2, 'B-03: üye kendi bildirimlerini görür');
select is(
  (select count(*)::int from public.referrals),
  0, 'F-13: getirilen üye de referans tablosunu doğrudan göremez');

-- ---------------------------------------------------------------------------
-- Y-05: eğitmen
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select is(
  (select count(*)::int from public.member_packages),
  0, 'Y-05: eğitmen üye paketlerini göremez');
select is(
  (select count(*)::int from public.wallets where member_id = ct.id('ma')),
  0, 'Y-05: eğitmen üyenin cüzdanını göremez');
select is(
  (select count(*)::int from public.wallet_ledger),
  0, 'Y-05: eğitmen cüzdan hareketlerini göremez');
select is(
  (select count(*)::int from public.credit_ledger),
  0, 'Y-05: eğitmen hak hareketlerini göremez');
select is(
  (select count(*)::int from public.profiles),
  1, 'Y-05: eğitmen yalnızca kendi profilini görür (boy/kilo/doğum tarihi kapalı)');
select is(
  (select count(*)::int from public.package_freezes),
  0, 'Y-05: eğitmen dondurma kayıtlarını göremez');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('ma')),
  0, 'Y-05: eğitmen üyenin bildirimlerini göremez');
select is(
  (select count(*)::int from public.audit_log),
  0, 'Y-05: eğitmen denetim kayıtlarını göremez');
select is(
  (select count(*)::int from public.referrals),
  0, 'Y-05: eğitmen referansları göremez');
select is(
  (select array_agg(class_id) from public.reservations),
  array[ct.id('c_t1')], 'Y-05: eğitmen yalnızca kendi dersinin rezervasyonunu görür');
select is(
  (select array_agg(full_name) from public.class_participants(ct.id('c_t1'))),
  array['Test ma'], 'Y-05: eğitmen kendi dersinin katılımcı adını görür');
select is(
  (select count(*)::int from public.class_participants(ct.id('c_t2'))),
  0, 'Y-05: eğitmen başka eğitmenin dersinin katılımcılarını göremez');
select ok(
  exists (select 1 from public.search_members('test ma') s where s.id = ct.id('ma')),
  'Y-05: eğitmen üye aramasında adı görür');
select is(
  (select count(*)::int from public.sales),
  1, 'Y-05: eğitmen kendi yaptığı satışı görür');
select is(
  (select count(*)::int from public.admin_class_reservations(ct.id('c_t1'))),
  0, 'Y-05: eğitmen yönetici rezervasyon listesini göremez');
select is(
  (select count(*)::int from public.admin_search_users('')),
  0, 'Y-05: eğitmen tüm kullanıcıları arayamaz');
select is(
  (select count(*)::int from public.admin_list_referrals()),
  0, 'Y-05: eğitmen referans panelini göremez');

-- Y-05: eğitmen yönetici işlemlerini çağıramaz
select throws_ok(
  $$select public.assign_package(ct.id('ma'), ct.id('def_a8'), ct.id('k_tr_x1'), true)$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen assign_package çağıramaz');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('ma'), 500, ct.id('k_tr_x2'))$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_wallet_topup çağıramaz');
select throws_ok(
  $$select public.admin_wallet_adjust(ct.id('ma'), 5, 'deneme', ct.id('k_tr_x3'))$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_wallet_adjust çağıramaz');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_sale_ma'), ct.id('k_tr_x4'))$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_reverse_wallet_entry çağıramaz');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_ma'), ct.today() + 1, ct.today() + 2)$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen freeze_package çağıramaz');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_ma'))$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_end_freeze çağıramaz');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_ma'), 5, 'deneme')$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_adjust_credits çağıramaz');
select throws_ok(
  $$select public.admin_set_no_show(ct.res('k_ma_t1'))$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_set_no_show çağıramaz');
select throws_ok(
  $$select public.admin_set_role(ct.id('trainer'), 'admin')$$,
  '42501', 'FORBIDDEN', 'Y-02: eğitmen kendi rolünü yükseltemez');
select throws_ok(
  $$select public.admin_set_active(ct.id('ma'), false)$$,
  '42501', 'FORBIDDEN', 'Y-05: eğitmen admin_set_active çağıramaz');
select throws_ok(
  $$select public.admin_decide_referral(ct.id('herhangi_referans'), true)$$,
  '42501', 'FORBIDDEN', 'F-05: eğitmen referans kararı veremez');
select throws_ok(
  $$select public.admin_create_referral(ct.id('trainer'), ct.id('mb'))$$,
  '42501', 'FORBIDDEN', 'F-16: eğitmen elle referans ekleyemez');
select throws_ok(
  $$select public.book_class(ct.id('c_t1'), ct.id('k_tr_x5'), ct.id('mb'))$$,
  '42501', 'FORBIDDEN', 'R-01: eğitmen üye adına rezervasyon yapamaz');
select throws_ok(
  $$update public.profiles set role = 'admin' where id = ct.id('trainer')$$,
  '42501', NULL, 'Y-02: eğitmen rol alanını doğrudan değiştiremez');
select throws_ok(
  $$insert into public.products (name, price) values ('pgTAP izinsiz ürün', 1)$$,
  '42501', NULL, 'Y-06: eğitmen ürün tanımlayamaz');

select ct.login('trainer2');
select is(
  (select count(*)::int from public.sales),
  0, 'Y-05: eğitmen başka eğitmenin satışını göremez');
select is(
  (select array_agg(class_id) from public.reservations),
  array[ct.id('c_t2')], 'Y-05: ikinci eğitmen de yalnızca kendi dersinin rezervasyonunu görür');

reset role;
select is(
  (select count(*)::int from public.member_packages where member_id = ct.id('ma')),
  1, 'Y-05: reddedilen eğitmen çağrıları paket yaratmadı');
select is(
  (select balance from public.wallets where member_id = ct.id('ma')),
  70.00::numeric, 'Y-05: reddedilen eğitmen çağrıları bakiyeyi değiştirmedi (100 - 30)');

-- ---------------------------------------------------------------------------
-- Y-02, Y-06: yönetici
-- ---------------------------------------------------------------------------
select ct.login('admin');
select is(
  (select count(*)::int from public.member_packages
   where member_id in (ct.id('ma'), ct.id('mb'))),
  2, 'Y-06: yönetici tüm üye paketlerini görür');
select is(
  (select count(*)::int from public.profiles
   where id in (ct.id('admin'), ct.id('trainer'), ct.id('trainer2'), ct.id('ma'), ct.id('mb'))),
  5, 'Y-06: yönetici tüm profilleri görür');
select is(
  (select count(*)::int from public.reservations where member_id = ct.id('ma')),
  2, 'Y-06: yönetici tüm rezervasyonları görür');
select is(
  (select count(*)::int from public.wallet_ledger where member_id = ct.id('ma')),
  2, 'Y-06: yönetici cüzdan hareketlerini görür');
select is(
  (select count(*)::int from public.referrals where referred_id = ct.id('ma')),
  1, 'F-14: yönetici referansları görür');
select ok(
  (select count(*) > 0 from public.audit_log where actor_id = ct.id('admin')),
  'Y-09: yönetici denetim kayıtlarını görür');
select throws_ok(
  $$select public.admin_set_role(ct.id('admin'), 'member')$$,
  'P0001', 'CANNOT_DEMOTE_SELF', 'Y-02: yönetici kendi rolünü düşüremez');
select throws_ok(
  $$select public.admin_set_active(ct.id('admin'), false)$$,
  'P0001', 'CANNOT_DEACTIVATE_SELF', 'Y-02: yönetici kendini pasifleştiremez');

-- ---------------------------------------------------------------------------
-- Y-07: pasif hesap hiçbir role sahip sayılmaz
-- ---------------------------------------------------------------------------
select lives_ok(
  $$select public.admin_set_active(ct.id('mb'), false)$$,
  'Hazırlık: yönetici mb hesabını pasife aldı');
select lives_ok(
  $$select public.admin_set_active(ct.id('trainer2'), false)$$,
  'Hazırlık: yönetici ikinci eğitmeni pasife aldı');

select ct.login('mb');
select throws_ok(
  $$select public.book_class(ct.id('c_t1'), ct.id('k_mb_pasif'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'Y-07: pasif üye rezervasyon yapamaz');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_ma_t1'))$$,
  '42501', 'UNAUTHENTICATED', 'Y-07: pasif hesap iptal işlemi yapamaz');

select ct.login('trainer2');
select throws_ok(
  $$select public.sell_product(ct.id('ma'), ct.id('p30'), 1, ct.id('k_tr2_pasif'))$$,
  '42501', 'FORBIDDEN', 'Y-07: pasif eğitmen satış yapamaz');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() + interval '9 days')$$,
  '42501', 'FORBIDDEN', 'Y-07: pasif eğitmen ders açamaz');
select is(
  (select count(*)::int from public.reservations),
  0, 'Y-07: pasif eğitmen kendi dersinin rezervasyonlarını da göremez');

-- ---------------------------------------------------------------------------
-- Y-08: giriş yapmamış istemci (anon)
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select count(*) from public.profiles$$,
  '42501', NULL, 'Y-08: anon profilleri okuyamaz');
select throws_ok(
  $$select count(*) from public.classes$$,
  '42501', NULL, 'Y-08: anon ders takvimini okuyamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_t1'), ct.id('k_anon'))$$,
  '42501', NULL, 'Y-08: anon book_class çağıramaz');
select throws_ok(
  $$select * from public.list_trainers()$$,
  '42501', NULL, 'Y-08: anon list_trainers çağıramaz');
reset role;

select * from finish();
rollback;
