-- Casper Training Studio — pgTAP: Rezervasyon: kontroller, idempotency, kontenjan, ders açma
-- Kurallar: R-01..R-11, S-01..S-04, P-04, D-06, I-05
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(59);

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
  perform ct.make_user(u.name)
  from unnest(array['m1', 'm2', 'm_exp', 'm_zero', 'm_fz', 'm_fz2']) u(name);
  perform ct.make_user('g' || g) from generate_series(1, 7) g;
end
$do$;

insert into public.categories (id, name) values
  (ct.id('cat_a'), 'pgTAP Kategori A'),
  (ct.id('cat_b'), 'pgTAP Kategori B');

insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price)
values
  (ct.id('def_a8'), ct.id('cat_a'), 'pgTAP A 8', 8, 30, 1000);

do $do$
begin
  perform ct.make_class('c1', 'trainer', 'cat_a', now() + interval '1 day');
  perform ct.make_class('c2', 'trainer', 'cat_a', now() + interval '2 days');
  perform ct.make_class('c_cancelled', 'trainer', 'cat_a', now() + interval '1 day');
  perform ct.make_class('c_started', 'trainer', 'cat_a', now() - interval '1 minute');
  perform ct.make_class('c_now', 'trainer', 'cat_a', now());
  perform ct.make_class('c_catb', 'trainer', 'cat_b', now() + interval '1 day');
  perform ct.make_class('c_after_end', 'trainer', 'cat_a', now() + interval '31 days');
  perform ct.make_class('c_at_end', 'trainer', 'cat_a', now() + interval '30 days');
  perform ct.make_class('c_before_end', 'trainer', 'cat_a',
                        now() + interval '30 days' - interval '1 second');
  perform ct.make_class('c_ind', 'trainer', 'cat_a', now() + interval '3 days', 'individual');
  perform ct.make_class('c_grp', 'trainer', 'cat_a', now() + interval '4 days', 'group');
  perform ct.make_class('c_admin', 'trainer', 'cat_a', now() + interval '5 days');
  perform ct.make_class('c_fz_in', 'trainer', 'cat_a', ct.ist_noon(6));
  perform ct.make_class('c_fz_after', 'trainer', 'cat_a', ct.ist_noon(9));
end
$do$;

update public.classes
set status = 'cancelled', cancelled_at = now(), cancelled_by = ct.id('admin')
where id = ct.id('c_cancelled');

select ct.login('admin');
select is(
  (select count(p.id)::int
   from unnest(array['m1', 'm2', 'm_exp', 'm_zero', 'm_fz', 'm_fz2',
                     'g1', 'g2', 'g3', 'g4', 'g5', 'g6', 'g7']) u(name),
        lateral public.assign_package(
          ct.id(u.name), ct.id('def_a8'), ct.id('k_pkg_' || u.name)) p),
  13, 'Hazırlık: 13 üyeye A kategorisinde 8 derslik paket atandı');

-- ---------------------------------------------------------------------------
-- Rezervasyon + hak düşümü tek işlemde
-- ---------------------------------------------------------------------------
select ct.login('m1');
select is(
  (select status::text from public.book_class(ct.id('c1'), ct.id('k_m1_c1'))),
  'booked', 'R-01: üye kendi adına rezervasyon yapar');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  7, 'R-07: rezervasyon 1 hak düşer (8 - 1)');
select is(
  (select count(*)::int from public.credit_ledger
   where reservation_id = ct.res('k_m1_c1') and entry_type = 'booking'
     and delta = -1 and balance_after = 7),
  1, 'R-11: tek booking (-1) hareketi, işlem sonrası bakiye 7');
select is(
  (select booked_count from public.classes where id = ct.id('c1')),
  1, 'Dersin dolu kontenjanı 1 arttı');
select ok(
  (select member_package_id = ct.pkg('k_pkg_m1') and booked_by = ct.id('m1')
   from public.reservations where id = ct.res('k_m1_c1')),
  'Rezervasyon kullanılan pakete ve yapan kişiye bağlandı');

-- ---------------------------------------------------------------------------
-- R-10: idempotency
-- ---------------------------------------------------------------------------
select ct.login('m1');
select is(
  (select id from public.book_class(ct.id('c1'), ct.id('k_m1_c1'))),
  ct.res('k_m1_c1'), 'R-10: aynı anahtar aynı rezervasyonu döndürür');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  7, 'R-10: tekrarlanan istek ikinci kez hak düşmez');
select is(
  (select count(*)::int from public.credit_ledger
   where member_id = ct.id('m1') and entry_type = 'booking'),
  1, 'R-10/R-11: hâlâ tek booking hareketi var');
select is(
  (select count(*)::int from public.reservations
   where member_id = ct.id('m1') and class_id = ct.id('c1')),
  1, 'R-10: ikinci rezervasyon oluşmadı');
select is(
  (select booked_count from public.classes where id = ct.id('c1')),
  1, 'R-10: dolu kontenjan ikinci kez artmadı');

select ct.login('m1');
select throws_ok(
  $$select public.book_class(ct.id('c2'), ct.id('k_m1_c1'))$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'R-10: aynı anahtar başka ders için kullanılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c2'), null)$$,
  'P0001', 'IDEMPOTENCY_KEY_REQUIRED', 'R-10: anahtarsız istek reddedilir');

-- ---------------------------------------------------------------------------
-- R-08, R-02, R-03, R-05
-- ---------------------------------------------------------------------------
select throws_ok(
  $$select public.book_class(ct.id('c1'), ct.id('k_m1_c1_ikinci'))$$,
  'P0001', 'ALREADY_BOOKED', 'R-08: aynı derse ikinci rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_cancelled'), ct.id('k_m1_cancelled'))$$,
  'P0001', 'CLASS_CANCELLED', 'R-02: iptal edilmiş derse rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_started'), ct.id('k_m1_started'))$$,
  'P0001', 'CLASS_ALREADY_STARTED', 'R-02: başlamış derse rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_now'), ct.id('k_m1_now'))$$,
  'P0001', 'CLASS_ALREADY_STARTED', 'R-02: tam başlangıç anında rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('yok_boyle_ders'), ct.id('k_m1_yok'))$$,
  'P0002', 'CLASS_NOT_FOUND', 'Olmayan derse rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_catb'), ct.id('k_m1_catb'))$$,
  'P0001', 'NO_ACTIVE_PACKAGE', 'R-03/P-04: paket yalnızca kendi kategorisinde kullanılır');
select throws_ok(
  $$select public.book_class(ct.id('c_after_end'), ct.id('k_m1_after'))$$,
  'P0001', 'CLASS_AFTER_PACKAGE_END', 'R-05: paket bitişinden sonraki derse rezervasyon yapılamaz');
select throws_ok(
  $$select public.book_class(ct.id('c_at_end'), ct.id('k_m1_at_end'))$$,
  'P0001', 'CLASS_AFTER_PACKAGE_END', 'R-05: tam bitiş anındaki ders de kapsam dışıdır');
select lives_ok(
  $$select public.book_class(ct.id('c_before_end'), ct.id('k_m1_before_end'))$$,
  'R-05: bitişten 1 saniye önce başlayan derse rezervasyon yapılabilir');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m1')),
  6, 'Reddedilen istekler hak düşmedi (8 - 2 başarılı rezervasyon)');
select is(
  (select count(*)::int from public.reservations where member_id = ct.id('m1')),
  2, 'Reddedilen istekler rezervasyon yaratmadı');

-- ---------------------------------------------------------------------------
-- R-01: kim rezervasyon yapabilir
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select throws_ok(
  $$select public.book_class(ct.id('c2'), ct.id('k_trainer_c2'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'R-01: eğitmen rezervasyon yapamaz');

select ct.login('m2');
select throws_ok(
  $$select public.book_class(ct.id('c2'), ct.id('k_m2_baskasi'), ct.id('m1'))$$,
  '42501', 'FORBIDDEN', 'R-01: üye başka üye adına rezervasyon yapamaz');

select ct.login('admin');
select throws_ok(
  $$select public.book_class(ct.id('c2'), ct.id('k_admin_c2'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'R-01: yönetici kendi adına rezervasyon yapamaz');
select is(
  (select booked_by
   from public.book_class(ct.id('c_admin'), ct.id('k_admin_m2'), ct.id('m2'))),
  ct.id('admin'), 'R-01: yönetici üye adına rezervasyon yapar');

reset role;
select ok(
  (select member_id = ct.id('m2') and member_package_id = ct.pkg('k_pkg_m2')
   from public.reservations where id = ct.res('k_admin_m2')),
  'R-01: yöneticinin yaptığı rezervasyon üyenin paketinden düşer');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m2')),
  7, 'R-01: üye adına rezervasyon da 1 hak düşer');

-- ---------------------------------------------------------------------------
-- R-04: süresi dolmuş paket
-- ---------------------------------------------------------------------------
update public.member_packages
set activated_at = now() - interval '31 days', ends_at = now() - interval '1 day'
where id = ct.pkg('k_pkg_m_exp');

select ct.login('m_exp');
select throws_ok(
  $$select public.book_class(ct.id('c1'), ct.id('k_exp_c1'))$$,
  'P0001', 'PACKAGE_EXPIRED', 'R-04: süresi dolmuş paketle rezervasyon yapılamaz');

-- ---------------------------------------------------------------------------
-- R-07: hakkı bitmiş paket
-- ---------------------------------------------------------------------------
reset role;
update public.member_packages set remaining_credits = 0 where id = ct.pkg('k_pkg_m_zero');

select ct.login('m_zero');
select throws_ok(
  $$select public.book_class(ct.id('c1'), ct.id('k_zero_c1'))$$,
  'P0001', 'NO_CREDITS', 'R-07: hakkı bitmiş paketle rezervasyon yapılamaz');

reset role;
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_m_zero')),
  0, 'R-07: hak eksiye düşmedi');
select is(
  (select count(*)::int from public.reservations
   where member_id in (ct.id('m_zero'), ct.id('m_exp'))),
  0, 'R-04/R-07: reddedilen istekler rezervasyon yaratmadı');

-- ---------------------------------------------------------------------------
-- R-06 / D-06: dondurulmuş paket
-- ---------------------------------------------------------------------------
select ct.login('admin');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m_fz'), ct.today() + 5, ct.today() + 7)$$,
  'Hazırlık: m_fz paketi 5-7 gün sonrası için donduruldu');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m_fz2'), ct.today(), ct.today() + 1)$$,
  'Hazırlık: m_fz2 paketi bugünden itibaren donduruldu');

select ct.login('m_fz');
select throws_ok(
  $$select public.book_class(ct.id('c_fz_in'), ct.id('k_fz_in'))$$,
  'P0001', 'PACKAGE_FROZEN', 'R-06: dondurma aralığındaki derse rezervasyon yapılamaz');
select lives_ok(
  $$select public.book_class(ct.id('c_fz_after'), ct.id('k_fz_after'))$$,
  'R-06: ileri tarihli dondurmanın dışındaki derse rezervasyon yapılabilir');

select ct.login('m_fz2');
select throws_ok(
  $$select public.book_class(ct.id('c2'), ct.id('k_fz2_c2'))$$,
  'P0001', 'PACKAGE_FROZEN', 'R-06/D-06: dondurma sürerken hiçbir derse rezervasyon yapılamaz');

-- ---------------------------------------------------------------------------
-- R-09: kontenjan (tek oturumda; eşzamanlı sürüm tool/concurrency içindedir)
-- ---------------------------------------------------------------------------
select ct.login('g1');
select lives_ok(
  $$select public.book_class(ct.id('c_ind'), ct.id('k_ind_g1'))$$,
  'S-02: bireysel dersin tek yeri alındı');

select ct.login('g2');
select throws_ok(
  $$select public.book_class(ct.id('c_ind'), ct.id('k_ind_g2'))$$,
  'P0001', 'CLASS_FULL', 'R-09: dolu bireysel derse rezervasyon yapılamaz');

select ct.login('admin');
select is(
  (select count(r.id)::int
   from generate_series(1, 6) g,
        lateral public.book_class(
          ct.id('c_grp'), ct.id('k_grp_g' || g), ct.id('g' || g)) r),
  6, 'S-02: grup dersine 6 üye rezervasyon yaptı');

select ct.login('g7');
select throws_ok(
  $$select public.book_class(ct.id('c_grp'), ct.id('k_grp_g7'))$$,
  'P0001', 'CLASS_FULL', 'R-09: 7. üye dolu grup dersine giremez');

reset role;
select ok(
  (select booked_count = 6 and booked_count = capacity
   from public.classes where id = ct.id('c_grp')),
  'R-09: dolu kontenjan kapasiteye eşit (6)');
select is(
  (select count(*)::int from public.reservations
   where class_id = ct.id('c_grp') and status = 'booked'),
  6, 'R-09: tam 6 rezervasyon var');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_g7')),
  8, 'R-09: CLASS_FULL alan üyenin hakkı düşmedi');
select is(
  (select remaining_credits from public.member_packages where id = ct.pkg('k_pkg_g2')),
  7, 'R-09: g2 yalnızca grup dersi için hak harcadı (bireysel ders reddi hak düşmedi)');

-- I-05: iptal yer açar, bekleyen üye girebilir
select ct.login('admin');
select lives_ok(
  $$select public.cancel_reservation(ct.res('k_grp_g1'), true)$$,
  'Hazırlık: yönetici g1 rezervasyonunu iadeli iptal etti');

select ct.login('g7');
select lives_ok(
  $$select public.book_class(ct.id('c_grp'), ct.id('k_grp_g7_tekrar'))$$,
  'I-05: iptalle açılan yere başka üye rezervasyon yapabilir');

reset role;
select is(
  (select booked_count from public.classes where id = ct.id('c_grp')),
  6, 'I-05/R-09: dolu kontenjan yeniden 6');

-- ---------------------------------------------------------------------------
-- S-01..S-04: ders açma
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select ok(
  (select trainer_id = ct.id('trainer') and capacity = 6 and status = 'scheduled'
          and ends_at = starts_at + interval '60 minutes'
   from public.create_class(ct.id('cat_a'), 'group', now() + interval '20 days')),
  'S-01/S-02/S-03: eğitmen kendi adına 6 kişilik, 60 dk grup dersi açar');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'individual',
                               now() + interval '20 days 30 minutes')$$,
  'P0001', 'TRAINER_BUSY', 'S-04: aynı eğitmenin çakışan dersi açılamaz');
select is(
  (select capacity
   from public.create_class(ct.id('cat_a'), 'individual',
                            now() + interval '20 days 60 minutes', 30)),
  1, 'S-02/S-04: bitişik saatte bireysel ders açılır, kapasite 1');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() - interval '1 minute')$$,
  'P0001', 'INVALID_CLASS_TIME', 'S-03: geçmişe ders açılamaz');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() + interval '22 days', 10)$$,
  'P0001', 'INVALID_DURATION', 'S-03: süre 15 dakikadan kısa olamaz');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() + interval '22 days',
                               60, null, ct.id('trainer2'))$$,
  '42501', 'FORBIDDEN', 'S-01: eğitmen başka eğitmen adına ders açamaz');

select ct.login('m1');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() + interval '22 days')$$,
  '42501', 'FORBIDDEN', 'S-01: üye ders açamaz');

select ct.login('admin');
select throws_ok(
  $$select public.create_class(ct.id('cat_a'), 'group', now() + interval '22 days')$$,
  'P0001', 'TRAINER_REQUIRED', 'S-01: yönetici eğitmen seçmeden ders açamaz');
select is(
  (select trainer_id
   from public.create_class(ct.id('cat_a'), 'group', now() + interval '20 days',
                            60, null, ct.id('trainer2'))),
  ct.id('trainer2'), 'S-01: yönetici herhangi bir eğitmen adına ders açar');

select * from finish();
rollback;
