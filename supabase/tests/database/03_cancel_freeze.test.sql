-- Casper Training Studio — pgTAP: İptal, ders iptali, dondurma, erken bitirme, elle hak düzeltme, gelmedi
-- Kurallar: I-01..I-07, S-06, D-01..D-07, P-12
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(120);

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
  perform ct.make_user('trainer2', 'trainer');
  perform ct.make_user('m' || g) from generate_series(1, 6) g;
end
$do$;

insert into public.categories (id, name) values (ct.id('cat_a'), 'pgTAP Kategori A');

insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price)
values
  (ct.id('def_a8'), ct.id('cat_a'), 'pgTAP A 8', 8, 30, 1000);

do $do$
begin
  -- İptal sınırı: now() transaction boyunca sabittir, bu yüzden sınır tam ölçülür
  perform ct.make_class('c_2h',  'trainer', 'cat_a', now() + interval '2 hours');
  perform ct.make_class('c_2hm', 'trainer', 'cat_a',
                        now() + interval '2 hours' - interval '1 second');
  perform ct.make_class('c_far',  'trainer', 'cat_a', now() + interval '3 days');
  perform ct.make_class('c_cls',  'trainer', 'cat_a', now() + interval '5 days');
  perform ct.make_class('c_cls2', 'trainer', 'cat_a', now() + interval '6 days');
  perform ct.make_class('c_started_t', 'trainer', 'cat_a', now() - interval '10 minutes');
  perform ct.make_class('c_ns', 'trainer', 'cat_a', now() + interval '1 day');
  -- Dondurma senaryosu (İstanbul gününe göre)
  perform ct.make_class('c_f1', 'trainer', 'cat_a', ct.ist_noon(5));
  perform ct.make_class('c_f2', 'trainer', 'cat_a', ct.ist_noon(6));
  perform ct.make_class('c_f3', 'trainer', 'cat_a', ct.ist_noon(10));
  perform ct.make_class('c_e1', 'trainer', 'cat_a', ct.ist_noon(6) + interval '2 hours');
  perform ct.make_class('c_e2', 'trainer', 'cat_a', ct.ist_noon(8));
end
$do$;

select ct.login('admin');
select is(
  (select count(p.id)::int
   from generate_series(1, 6) g,
        lateral public.assign_package(
          ct.id('m' || g), ct.id('def_a8'), ct.id('k_pkg_m' || g)) p),
  6, 'Hazırlık: 6 üyeye 8 derslik paket atandı');

select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('c_2h'), ct.id('k_2h'))$$,
  'Hazırlık: m1 tam 2 saat sonraki derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_2hm'), ct.id('k_2hm'))$$,
  'Hazırlık: m1 1 sa 59 dk 59 sn sonraki derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_far'), ct.id('k_far'))$$,
  'Hazırlık: m1 3 gün sonraki derse rezervasyon yaptı');

-- ---------------------------------------------------------------------------
-- I-01, I-02, I-05: üyenin iptali ve 2 saat sınırı
-- ---------------------------------------------------------------------------
select is(
  (select status::text from public.cancel_reservation(ct.res('k_2h'))),
  'cancelled', 'I-01: derse tam 2 saat kala üye iptal edebilir');

reset role;
select ok(
  (select credit_refunded and cancelled_by = ct.id('m1') and cancelled_at = now()
   from public.reservations where id = ct.res('k_2h')),
  'I-02: zamanında iptalde hak iade edildi olarak işaretlenir');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'I-02: hak geri geldi (8 - 3 + 1)');
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_2h') and entry_type = 'refund'
     and delta = 1 and balance_after = 6),
  1, 'I-02/R-11: tek refund (+1) hareketi');
select is(
  (select booked_count from public.classes where id = ct.id('c_2h')),
  0, 'I-05: iptal dersin dolu kontenjanını 1 azaltır');

select ct.login('m1');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_2hm'))$$,
  'P0001', 'CANCEL_WINDOW_CLOSED', 'I-01: 2 saatten 1 saniye az kaldıysa üye iptal edemez');

reset role;
select is(
  (select status::text from public.reservations where id = ct.res('k_2hm')),
  'booked', 'I-01: reddedilen iptalde rezervasyon durur');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'I-01: reddedilen iptalde hak değişmez');
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_2hm') and entry_type = 'refund'),
  0, 'I-01: reddedilen iptalde iade hareketi yok');

-- ---------------------------------------------------------------------------
-- I-04: tekrarlanan iptal
-- ---------------------------------------------------------------------------
select ct.login('m1');
select is(
  (select status::text from public.cancel_reservation(ct.res('k_2h'))),
  'cancelled', 'I-04: tekrarlanan iptal mevcut iptal kaydını döndürür');

reset role;
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_2h') and entry_type = 'refund'),
  1, 'I-04: ikinci iade hareketi oluşmadı');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'I-04: hak ikinci kez artmadı');
select is(
  (select booked_count from public.classes where id = ct.id('c_2h')),
  0, 'I-04: dolu kontenjan ikinci kez azalmadı');

-- ---------------------------------------------------------------------------
-- I-07: başkasının rezervasyonu
-- ---------------------------------------------------------------------------
select ct.login('m2');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_far'))$$,
  'P0002', 'RESERVATION_NOT_FOUND', 'I-07: üye başkasının rezervasyonunu iptal edemez');

select ct.login('trainer');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_far'))$$,
  'P0002', 'RESERVATION_NOT_FOUND', 'Eğitmen tek tek rezervasyon iptal edemez');

select ct.login('m1');
select throws_ok(
  $$select public.cancel_reservation(ct.id('yok_boyle_rezervasyon'))$$,
  'P0002', 'RESERVATION_NOT_FOUND', 'Olmayan rezervasyon iptal edilemez');

-- ---------------------------------------------------------------------------
-- I-03: yönetici iptali ve iade seçimi
-- ---------------------------------------------------------------------------
select ct.login('admin');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_far'))$$,
  'P0001', 'REFUND_CHOICE_REQUIRED', 'I-03: yönetici iade seçimini açıkça yapmak zorundadır');
select is(
  (select status::text
   from public.cancel_reservation(ct.res('k_far'), false, 'Üye haber vermedi')),
  'cancelled', 'I-03: yönetici iadesiz iptal edebilir');

reset role;
select ok(
  (select not credit_refunded and cancelled_by = ct.id('admin')
          and cancel_reason = 'Üye haber vermedi'
   from public.reservations where id = ct.res('k_far')),
  'I-03: iadesiz iptal kaydı (iade yok, yapan yönetici, neden)');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'I-03: iadesiz iptalde hak geri gelmez');
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_far') and entry_type = 'refund'),
  0, 'I-03: iadesiz iptalde iade hareketi yok');
select is(
  (select booked_count from public.classes where id = ct.id('c_far')),
  0, 'I-05: iadesiz iptal de yer açar');
select is(
  (select count(*)::int from public.audit_log
   where action = 'cancel_reservation' and entity_id = ct.res('k_far')::text),
  1, 'Y-09: yönetici iptali denetim kaydına yazılır');

select ct.login('admin');
select is(
  (select credit_refunded from public.cancel_reservation(ct.res('k_far'), true)),
  false, 'I-04: iptal edilmiş kayıtta sonradan gelen iadeli istek iade yaratmaz');
select is(
  (select status::text from public.cancel_reservation(ct.res('k_2hm'), true)),
  'cancelled', 'I-03: yönetici 2 saat sınırından sonra da iptal edebilir');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  7, 'I-03: yönetici iadeli iptalinde hak geri gelir (6 + 1)');

-- ---------------------------------------------------------------------------
-- R-08, R-10: iptalden sonra yeniden rezervasyon
-- ---------------------------------------------------------------------------
select ct.login('m1');
select is(
  (select status::text from public.book_class(ct.id('c_far'), ct.id('k_far'))),
  'cancelled', 'R-10: eski anahtar yeni rezervasyon yaratmaz, ilk kaydı döndürür');
select is(
  (select status::text from public.book_class(ct.id('c_far'), ct.id('k_far_yeni'))),
  'booked', 'R-08: iptalden sonra yeni anahtarla yeniden rezervasyon yapılabilir');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'R-08: yeniden rezervasyon 1 hak düşer (7 - 1)');

-- ---------------------------------------------------------------------------
-- S-06: dersin tamamının iptali
-- ---------------------------------------------------------------------------
select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('c_cls'), ct.id('k_cls_m1'))$$,
  'Hazırlık: m1 iptal edilecek derse rezervasyon yaptı');
select throws_ok(
  $$select public.cancel_class(ct.id('c_cls'))$$,
  '42501', 'FORBIDDEN', 'S-06: üye ders iptal edemez');

select ct.login('m2');
select lives_ok(
  $$select public.book_class(ct.id('c_cls'), ct.id('k_cls_m2'))$$,
  'Hazırlık: m2 iptal edilecek derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('c_cls2'), ct.id('k_cls2_m2'))$$,
  'Hazırlık: m2 ikinci derse rezervasyon yaptı');

select ct.login('trainer2');
select throws_ok(
  $$select public.cancel_class(ct.id('c_cls'))$$,
  '42501', 'FORBIDDEN', 'S-06: eğitmen başka eğitmenin dersini iptal edemez');

select ct.login('trainer');
select throws_ok(
  $$select public.cancel_class(ct.id('c_started_t'))$$,
  'P0001', 'CLASS_ALREADY_STARTED', 'S-06: eğitmen başlamış dersi iptal edemez');
select throws_ok(
  $$select public.cancel_class(ct.id('yok_boyle_ders'))$$,
  'P0002', 'CLASS_NOT_FOUND', 'Olmayan ders iptal edilemez');
select is(
  (select status::text from public.cancel_class(ct.id('c_cls'), false, 'Eğitmen hasta')),
  'cancelled', 'S-06: eğitmen kendi dersini iptal eder');

reset role;
select is(
  (select count(*)::int from public.reservations
   where class_id = ct.id('c_cls') and status = 'cancelled' and credit_refunded),
  2, 'S-06: eğitmen iptalinde tüm rezervasyonlar her zaman iadeli iptal edilir');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'S-06: m1 hakkı geri geldi');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m2')),
  7, 'S-06: m2 hakkı geri geldi (8 - 2 + 1)');
select is(
  (select booked_count from public.classes where id = ct.id('c_cls')),
  0, 'S-06: iptal edilen dersin dolu kontenjanı sıfırlandı');

select ct.login('trainer');
select is(
  (select status::text from public.cancel_class(ct.id('c_cls'))),
  'cancelled', 'S-06: tekrarlanan ders iptali mevcut kaydı döndürür');

reset role;
select is(
  (select count(*)::int from public.credit_ledger cl
   join public.reservations r on r.id = cl.reservation_id
   where r.class_id = ct.id('c_cls') and cl.entry_type = 'refund'),
  2, 'S-06/I-04: tekrarlanan ders iptali ikinci iade yaratmadı');

select ct.login('admin');
select is(
  (select status::text from public.cancel_class(ct.id('c_cls2'), false, 'Salon kapalı')),
  'cancelled', 'S-06: yönetici dersi iadesiz iptal edebilir');

reset role;
select ok(
  (select status = 'cancelled' and not credit_refunded
   from public.reservations where id = ct.res('k_cls2_m2')),
  'S-06: yönetici iadesiz seçince rezervasyon iadesiz iptal edilir');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m2')),
  7, 'S-06: iadesiz ders iptalinde hak geri gelmez');

-- ---------------------------------------------------------------------------
-- D-01, D-02: dondurma yetkisi ve doğrulamalar
-- ---------------------------------------------------------------------------
select ct.login('m3');
select is(
  (select count(r.id)::int
   from unnest(array['c_f1', 'c_f2', 'c_f3']) u(name),
        lateral public.book_class(ct.id(u.name), ct.id('k_' || u.name)) r),
  3, 'Hazırlık: m3 dondurma aralığında 2, dışında 1 derse rezervasyon yaptı');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 5, ct.today() + 7)$$,
  '42501', 'FORBIDDEN', 'D-01: üye paket donduramaz');

select ct.login('trainer');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 5, ct.today() + 7)$$,
  '42501', 'FORBIDDEN', 'D-01/Y-05: eğitmen paket donduramaz');

reset role;
update public.member_packages set status = 'terminated', closed_at = now()
where id = ct.pkg('k_pkg_m6');

select ct.login('admin');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() - 1, ct.today() + 1)$$,
  'P0001', 'FREEZE_IN_PAST', 'D-02: başlangıç bugünden önce olamaz');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 3, ct.today() + 2)$$,
  'P0001', 'INVALID_FREEZE_RANGE', 'D-02: bitiş başlangıçtan önce olamaz');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 1, ct.today() + 400)$$,
  'P0001', 'INVALID_FREEZE_RANGE', 'D-02: tek seferde en fazla 365 gün dondurulur');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 31, ct.today() + 32)$$,
  'P0001', 'FREEZE_OUTSIDE_PACKAGE', 'D-02: aralık paket bitişinden önce başlamalıdır');
select throws_ok(
  $$select public.freeze_package(ct.id('yok_boyle_paket'), ct.today() + 1, ct.today() + 2)$$,
  'P0002', 'PACKAGE_NOT_FOUND', 'D-02: olmayan paket dondurulamaz');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m6'), ct.today() + 1, ct.today() + 2)$$,
  'P0001', 'PACKAGE_NOT_ACTIVE', 'D-02: aktif olmayan paket dondurulamaz');

-- ---------------------------------------------------------------------------
-- D-04, D-05: dondurma — aralıktaki 2 rezervasyon iptal, 1 korunur, bitiş uzar
-- ---------------------------------------------------------------------------
select is(
  (select days
   from public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 5, ct.today() + 7, 'Tatil')),
  3, 'D-01: her iki gün dahil 3 günlük dondurma kaydı');

reset role;
select is(
  (select ends_at from public.member_packages where id = ct.pkg('k_pkg_m3')),
  now() + interval '33 days', 'D-04: dondurulan 3 gün paket bitişine eklendi (30 + 3)');
select ok(
  (select starts_at = ct.ist_midnight(5) and ends_at = ct.ist_midnight(8)
   from public.package_freezes where id = ct.frz('k_pkg_m3')),
  'D-01: aralık İstanbul gününe göre [başlangıç 00:00, bitişten sonraki gün 00:00)');
select is(
  (select count(*)::int from public.reservations
   where id in (ct.res('k_c_f1'), ct.res('k_c_f2'))
     and status = 'cancelled' and credit_refunded
     and cancel_reason = 'Paket donduruldu'),
  2, 'D-05: aralıktaki 2 rezervasyon iadeli iptal edildi');
select is(
  (select status::text from public.reservations where id = ct.res('k_c_f3')),
  'booked', 'D-05: aralık dışındaki rezervasyon korundu');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m3')),
  7, 'D-05: 2 hak iade edildi (8 - 3 + 2)');
select is(
  (select count(*)::int from public.credit_ledger
   where member_id = ct.id('m3') and entry_type = 'refund' and delta = 1),
  2, 'D-05: 2 refund hareketi');
select is(
  (select array_agg(booked_count order by starts_at) from public.classes
   where id in (ct.id('c_f1'), ct.id('c_f2'), ct.id('c_f3'))),
  array[0, 0, 1], 'D-05/I-05: iptal edilen derslerde yer açıldı, korunan derste durdu');
select is(
  (select count(*)::int from public.audit_log
   where action = 'freeze_package' and entity_id = ct.pkg('k_pkg_m3')::text),
  1, 'Y-09: dondurma denetim kaydına yazılır');

-- ---------------------------------------------------------------------------
-- D-03: çakışan dondurma; D-06: dondurma aralığına rezervasyon
-- ---------------------------------------------------------------------------
select ct.login('admin');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 7, ct.today() + 9)$$,
  'P0001', 'FREEZE_OVERLAP', 'D-03: son günüyle çakışan dondurma yapılamaz');
select throws_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 3, ct.today() + 5)$$,
  'P0001', 'FREEZE_OVERLAP', 'D-03: ilk günüyle çakışan dondurma yapılamaz');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m3'), ct.today() + 8, ct.today() + 8)$$,
  'D-03: bitişik (çakışmayan) ikinci dondurma yapılabilir');

reset role;
select is(
  (select ends_at from public.member_packages where id = ct.pkg('k_pkg_m3')),
  now() + interval '34 days', 'D-04: ikinci dondurmanın 1 günü de bitişe eklendi');
select is(
  (select status::text from public.reservations where id = ct.res('k_c_f3')),
  'booked', 'D-05: ikinci dondurma aralık dışındaki rezervasyona dokunmadı');

select ct.login('m3');
select throws_ok(
  $$select public.book_class(ct.id('c_f1'), ct.id('k_c_f1_tekrar'))$$,
  'P0001', 'PACKAGE_FROZEN', 'D-06: dondurma aralığındaki derse yeniden rezervasyon yapılamaz');

-- ---------------------------------------------------------------------------
-- D-07: dondurmayı erken bitirme
-- ---------------------------------------------------------------------------
select ct.login('m4');
select lives_ok(
  $$select public.book_class(ct.id('c_e1'), ct.id('k_e1'))$$,
  'Hazırlık: m4 dondurulacak aralıktaki derse rezervasyon yaptı');

select ct.login('admin');
select is(
  (select days
   from public.freeze_package(ct.pkg('k_pkg_m4'), ct.today() + 5, ct.today() + 9)),
  5, 'Hazırlık: m4 paketi 5 gün donduruldu');

select ct.login('trainer');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_m4'))$$,
  '42501', 'FORBIDDEN', 'D-07/Y-05: eğitmen dondurmayı bitiremez');

select ct.login('admin');
select throws_ok(
  $$select public.admin_end_freeze(ct.id('yok_boyle_dondurma'))$$,
  'P0002', 'FREEZE_NOT_FOUND', 'D-07: olmayan dondurma bitirilemez');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_m4'), ct.today() + 9)$$,
  'P0001', 'INVALID_FREEZE_RANGE', 'D-07: yeni son gün mevcut son günden önce olmalıdır');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_m4'), ct.today() + 12)$$,
  'P0001', 'INVALID_FREEZE_RANGE', 'D-07: erken bitirme ile dondurma uzatılamaz');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_m4'), ct.today() + 3)$$,
  'P0001', 'INVALID_FREEZE_RANGE', 'D-07: son gün ilk günden bir gün öncesinden küçük olamaz');
select is(
  (select ends_at from public.admin_end_freeze(ct.frz('k_pkg_m4'), ct.today() + 6)),
  now() + interval '32 days', 'D-07: kaldırılan 3 gün paket bitişinden düşüldü (35 - 3)');

reset role;
select ok(
  (select days = 2 and starts_at = ct.ist_midnight(5) and ends_at = ct.ist_midnight(7)
   from public.package_freezes where id = ct.frz('k_pkg_m4')),
  'D-07: dondurma kaydı 2 güne kısaldı');
select is(
  (select status::text from public.reservations where id = ct.res('k_e1')),
  'cancelled', 'D-07: dondurmada iptal edilen rezervasyon geri gelmez');

select ct.login('m4');
select lives_ok(
  $$select public.book_class(ct.id('c_e2'), ct.id('k_e2'))$$,
  'D-07: dondurmadan çıkarılan güne rezervasyon yapılabilir');
select throws_ok(
  $$select public.book_class(ct.id('c_e1'), ct.id('k_e1_tekrar'))$$,
  'P0001', 'PACKAGE_FROZEN', 'D-07: hâlâ dondurulmuş güne rezervasyon yapılamaz');

select ct.login('admin');
select is(
  (select ends_at from public.admin_end_freeze(ct.frz('k_pkg_m4'))),
  now() + interval '30 days',
  'D-07: başlamamış dondurma tamamen kaldırılınca bitiş ilk değerine döner');

reset role;
select is(
  (select count(*)::int from public.package_freezes
   where member_package_id = ct.pkg('k_pkg_m4')),
  0, 'D-07: başlamamış dondurma kaydı silindi');
select is(
  (select count(*)::int from public.audit_log
   where action = 'end_freeze' and details ->> 'package_id' = ct.pkg('k_pkg_m4')::text),
  2, 'Y-09: erken bitirme denetim kaydına yazılır');

-- Bugün başlamış dondurma: boş p_last_day ile dün biter (üye bugünden itibaren kullanır)
select ct.login('admin');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m4'), ct.today(), ct.today() + 2)$$,
  'Hazırlık: m4 paketi bugünden itibaren 3 gün donduruldu');

select ct.login('m4');
select throws_ok(
  $$select public.book_class(ct.id('c_f3'), ct.id('k_m4_f3'))$$,
  'P0001', 'PACKAGE_FROZEN', 'D-06: dondurma sürerken rezervasyon yapılamaz');

select ct.login('admin');
select is(
  (select ends_at from public.admin_end_freeze(ct.frz('k_pkg_m4'))),
  now() + interval '30 days', 'D-07: başlamış dondurma bitirilince eklenen günler geri alınır');

select ct.login('m4');
select lives_ok(
  $$select public.book_class(ct.id('c_f3'), ct.id('k_m4_f3'))$$,
  'D-07: dondurma bitince üye yeniden rezervasyon yapabilir');

reset role;
insert into public.package_freezes (member_package_id, starts_at, ends_at, days, created_by)
values (ct.pkg('k_pkg_m4'), ct.ist_midnight(-10), ct.ist_midnight(-7), 3, ct.id('admin'));

select ct.login('admin');
select throws_ok(
  $$select public.admin_end_freeze(ct.frz('k_pkg_m4'))$$,
  'P0001', 'FREEZE_ALREADY_ENDED', 'D-07: bitmiş dondurma değiştirilemez');

-- ---------------------------------------------------------------------------
-- P-12: elle hak düzeltme
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 1, 'deneme')$$,
  '42501', 'FORBIDDEN', 'P-12/Y-05: eğitmen hak düzeltemez');

select ct.login('admin');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 0, 'deneme')$$,
  'P0001', 'INVALID_CREDIT_DELTA', 'P-12: düzeltme 0 olamaz');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 101, 'deneme')$$,
  'P0001', 'INVALID_CREDIT_DELTA', 'P-12: düzeltme en fazla 100 olabilir');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 1, '   ')$$,
  'P0001', 'NOTE_REQUIRED', 'P-12: not zorunludur');
select throws_ok(
  $$select public.admin_adjust_credits(ct.id('yok_boyle_paket'), 1, 'deneme')$$,
  'P0002', 'PACKAGE_NOT_FOUND', 'P-12: olmayan paket düzeltilemez');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), -9, 'deneme')$$,
  'P0001', 'NO_CREDITS', 'P-12: hak 0 altına düşemez (8 - 9)');
select is(
  (select balance_after from public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 2, 'Telafi')),
  10, 'P-12: +2 düzeltme (8 + 2)');
select is(
  (select balance_after from public.admin_adjust_credits(ct.pkg('k_pkg_m5'), -10, 'Hata düzeltme')),
  0, 'P-12: hak tam 0 olana kadar düşülebilir');
select throws_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), -1, 'deneme')$$,
  'P0001', 'NO_CREDITS', 'P-12: 0 haktan düşülemez');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m5')),
  0, 'P-12: reddedilen düzeltmeler hakkı değiştirmedi');
select is(
  (select count(*)::int from public.credit_ledger
   where member_package_id = ct.pkg('k_pkg_m5') and entry_type = 'adjustment'),
  2, 'P-12: her başarılı düzeltme için bir adjustment hareketi');
select is(
  (select count(*)::int from public.audit_log
   where action = 'adjust_credits' and entity_id = ct.pkg('k_pkg_m5')::text),
  2, 'P-12/Y-09: düzeltmeler denetim kaydına yazılır');

-- ---------------------------------------------------------------------------
-- I-06: gelmedi işaretleme
-- ---------------------------------------------------------------------------
select ct.login('admin');
select lives_ok(
  $$select public.admin_adjust_credits(ct.pkg('k_pkg_m5'), 3, 'Test için hak')$$,
  'Hazırlık: m5 paketine 3 hak eklendi');

select ct.login('m5');
select lives_ok(
  $$select public.book_class(ct.id('c_ns'), ct.id('k_ns'))$$,
  'Hazırlık: m5 derse rezervasyon yaptı');

select ct.login('admin');
select throws_ok(
  $$select public.admin_set_no_show(ct.res('k_ns'))$$,
  'P0001', 'CLASS_NOT_STARTED', 'I-06: ders başlamadan gelmedi işaretlenemez');

reset role;
update public.classes
set starts_at = now() - interval '2 hours', ends_at = now() - interval '1 hour'
where id = ct.id('c_ns');

select ct.login('trainer');
select throws_ok(
  $$select public.admin_set_no_show(ct.res('k_ns'))$$,
  '42501', 'FORBIDDEN', 'I-06/Y-05: eğitmen gelmedi işaretleyemez');

select ct.login('m5');
select throws_ok(
  $$select public.cancel_reservation(ct.res('k_ns'))$$,
  'P0001', 'CANCEL_WINDOW_CLOSED', 'I-01: ders başladıktan sonra üye iptal edemez');

select ct.login('admin');
select throws_ok(
  $$select public.admin_set_no_show(ct.id('yok_boyle_rezervasyon'))$$,
  'P0002', 'RESERVATION_NOT_FOUND', 'I-06: olmayan rezervasyon işaretlenemez');
select is(
  (select status::text from public.admin_set_no_show(ct.res('k_ns'))),
  'no_show', 'I-06: yönetici ders başladıktan sonra gelmedi işaretler');
select is(
  (select status::text from public.admin_set_no_show(ct.res('k_ns'), true)),
  'no_show', 'I-06: tekrarlanan işaretleme aynı kaydı döndürür');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m5')),
  2, 'I-06: gelmedi işareti ek hak düşmez (3 - 1)');
select is(
  (select count(*)::int from public.credit_ledger where reservation_id = ct.res('k_ns')),
  1, 'I-06: yalnızca ilk booking hareketi var');
select is(
  (select booked_count from public.classes where id = ct.id('c_ns')),
  1, 'I-06: gelmedi işareti kontenjanı değiştirmez');

select ct.login('admin');
select is(
  (select status::text from public.admin_set_no_show(ct.res('k_ns'), false)),
  'booked', 'I-06: gelmedi işareti geri alınabilir');
select is(
  (select status::text from public.cancel_reservation(ct.res('k_ns'), false)),
  'cancelled', 'I-03: yönetici ders başladıktan sonra da iptal edebilir');
select throws_ok(
  $$select public.admin_set_no_show(ct.res('k_ns'), true)$$,
  'P0001', 'RESERVATION_NOT_ACTIVE', 'I-06: iptal edilmiş rezervasyon gelmedi işaretlenemez');

select * from finish();
rollback;
