-- Casper Training Studio — pgTAP: Bildirim kuyruğu: tetikleyici, tekrar etmeme, zamanlanmış görev, gönderici
-- Kurallar: B-01..B-03
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
  perform ct.make_user('m1');
  perform ct.make_user('m2');
end
$do$;

insert into public.categories (id, name) values (ct.id('cat_a'), 'pgTAP Kategori A');

insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price)
values
  (ct.id('def_a8'), ct.id('cat_a'), 'pgTAP A 8', 8, 30, 1000);

do $do$
begin
  perform ct.make_class('n1', 'trainer', 'cat_a', now() + interval '1 day');
  perform ct.make_class('n2', 'trainer', 'cat_a', now() + interval '2 days');
  perform ct.make_class('n3', 'trainer', 'cat_a', now() + interval '3 days');
  perform ct.make_class('n_ns', 'trainer', 'cat_a', now() + interval '4 days');
  perform ct.make_class('n_fz', 'trainer', 'cat_a', ct.ist_noon(6));
  -- Hatırlatma penceresi: (şimdi + 2 saat, şimdi + 3 saat]
  perform ct.make_class('n_soon', 'trainer', 'cat_a', now() + interval '2 hours 30 minutes');
  perform ct.make_class('n_2h', 'trainer', 'cat_a', now() + interval '2 hours');
  perform ct.make_class('n_3h', 'trainer', 'cat_a', now() + interval '3 hours');
end
$do$;

select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_pkg_m1'))$$,
  'Hazırlık: m1 paket aldı');
select lives_ok(
  $$select public.assign_package(ct.id('m2'), ct.id('def_a8'), ct.id('k_pkg_m2'))$$,
  'Hazırlık: m2 paket aldı');

reset role;
select is(
  (select count(*)::int from public.notifications
   where user_id in (ct.id('m1'), ct.id('m2'))),
  0, 'Başlangıçta bildirim yok (paket atama bildirim üretmez)');

-- ---------------------------------------------------------------------------
-- B-01, B-02: rezervasyon onayı bir kez kuyruğa girer
-- ---------------------------------------------------------------------------
select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n1'), ct.id('k_n1'))$$,
  'm1 rezervasyon yaptı');

reset role;
select is(
  (select count(*)::int from public.notifications
   where user_id = ct.id('m1') and kind = 'booking_confirmed'),
  1, 'B-01: rezervasyonda tek onay bildirimi kuyruğa girer');
select ok(
  (select status = 'pending'
          and title = 'Rezervasyon onaylandı'
          and body like 'pgTAP Kategori A dersi, %'
          and payload ->> 'reservation_id' = ct.res('k_n1')::text
          and payload ->> 'class_id' = ct.id('n1')::text
   from public.notifications
   where dedupe_key = 'booking_confirmed:' || ct.res('k_n1')),
  'B-02: onay bildirimi rezervasyona özgü dedupe_key ile bekliyor');

select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n1'), ct.id('k_n1'))$$,
  'm1 aynı isteği tekrar gönderdi');
select throws_ok(
  $$select public.book_class(ct.id('n1'), ct.id('k_n1_ikinci'))$$,
  'P0001', 'ALREADY_BOOKED', 'm1 aynı derse ikinci kez rezervasyon yapamadı');

reset role;
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m1')),
  1, 'B-02: tekrarlanan ve reddedilen istekler yeni bildirim üretmez');

-- ---------------------------------------------------------------------------
-- B-01, B-02: iptal bildirimi bir kez kuyruğa girer
-- ---------------------------------------------------------------------------
select ct.login('m1');
select lives_ok(
  $$select public.cancel_reservation(ct.res('k_n1'))$$,
  'm1 rezervasyonunu iptal etti');
select lives_ok(
  $$select public.cancel_reservation(ct.res('k_n1'))$$,
  'm1 iptal isteğini tekrar gönderdi');

reset role;
select is(
  (select count(*)::int from public.notifications
   where user_id = ct.id('m1') and kind = 'reservation_cancelled'),
  1, 'B-02: iptalde tek bildirim kuyruğa girer (tekrarlanan iptal dahil)');
select ok(
  (select title = 'Rezervasyon iptal edildi'
          and body like '%Ders hakkınız iade edildi.'
          and body not like '%Neden:%'
          and payload ->> 'refunded' = 'true'
   from public.notifications
   where dedupe_key = 'reservation_cancelled:' || ct.res('k_n1')),
  'B-01: üyenin kendi iptalinde iade bilgisi var, neden yok');

select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n1'), ct.id('k_n1b'))$$,
  'm1 aynı derse yeniden rezervasyon yaptı');

select ct.login('admin');
select lives_ok(
  $$select public.cancel_reservation(ct.res('k_n1b'), false, 'Salon kapalı')$$,
  'Yönetici rezervasyonu iadesiz iptal etti');

reset role;
select is(
  (select count(*)::int from public.notifications
   where user_id = ct.id('m1') and kind = 'booking_confirmed'),
  2, 'B-02: yeni rezervasyon kendi onay bildirimini üretir');
select ok(
  (select body like '%Neden: Salon kapalı. Ders hakkı iade edilmedi.'
          and payload ->> 'refunded' = 'false'
   from public.notifications
   where dedupe_key = 'reservation_cancelled:' || ct.res('k_n1b')),
  'B-01: yönetici iptalinde neden ve iade edilmediği bildirilir');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m1')),
  4, 'B-02: m1 için toplam 2 onay + 2 iptal bildirimi');

-- ---------------------------------------------------------------------------
-- Ders iptali: her katılımcıya bir bildirim
-- ---------------------------------------------------------------------------
select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n3'), ct.id('k_n3_m1'))$$,
  'm1 iptal edilecek derse rezervasyon yaptı');

select ct.login('m2');
select lives_ok(
  $$select public.book_class(ct.id('n3'), ct.id('k_n3_m2'))$$,
  'm2 iptal edilecek derse rezervasyon yaptı');

select ct.login('trainer');
select lives_ok(
  $$select public.cancel_class(ct.id('n3'), true, 'Eğitmen hasta')$$,
  'Eğitmen dersi iptal etti');
select lives_ok(
  $$select public.cancel_class(ct.id('n3'), true, 'Eğitmen hasta')$$,
  'Eğitmen ders iptalini tekrar gönderdi');

reset role;
select is(
  (select count(*)::int from public.notifications
   where kind = 'reservation_cancelled'
     and dedupe_key in ('reservation_cancelled:' || ct.res('k_n3_m1'),
                        'reservation_cancelled:' || ct.res('k_n3_m2'))),
  2, 'B-01: ders iptalinde her katılımcıya bir iptal bildirimi');
select ok(
  (select body like '%Neden: Eğitmen hasta. Ders hakkınız iade edildi.'
   from public.notifications
   where dedupe_key = 'reservation_cancelled:' || ct.res('k_n3_m2')),
  'B-01: ders iptali bildiriminde neden ve iade bilgisi var');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m2')),
  2, 'B-02: m2 için 1 onay + 1 iptal bildirimi (tekrarlanan ders iptali dahil)');

-- ---------------------------------------------------------------------------
-- Dondurma: iptal edilen rezervasyon için bildirim
-- ---------------------------------------------------------------------------
select ct.login('m2');
select lives_ok(
  $$select public.book_class(ct.id('n_fz'), ct.id('k_fz'))$$,
  'm2 dondurulacak aralıktaki derse rezervasyon yaptı');

select ct.login('admin');
select lives_ok(
  $$select public.freeze_package(ct.pkg('k_pkg_m2'), ct.today() + 5, ct.today() + 7)$$,
  'Yönetici m2 paketini dondurdu');

reset role;
select ok(
  (select body like '%Neden: Paket donduruldu. Ders hakkınız iade edildi.'
   from public.notifications
   where dedupe_key = 'reservation_cancelled:' || ct.res('k_fz')),
  'B-01/D-05: dondurmanın iptal ettiği rezervasyon için bildirim üretilir');

-- ---------------------------------------------------------------------------
-- Durum değişmeyen işlemler bildirim üretmez: aktarım ve gelmedi işareti
-- ---------------------------------------------------------------------------
select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n2'), ct.id('k_n2'))$$,
  'm1 aktarılacak rezervasyonu yaptı');

select ct.login('admin');
select lives_ok(
  $$select public.assign_package(ct.id('m1'), ct.id('def_a8'), ct.id('k_pkg_m1_yeni'), true)$$,
  'Yönetici m1 paketini yeniledi');

reset role;
select is(
  (select member_package_id from public.reservations where id = ct.res('k_n2')),
  ct.pkg('k_pkg_m1_yeni'), 'P-08: rezervasyon yeni pakete aktarıldı');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m1')),
  7, 'B-02: aktarım bildirim üretmez (3 onay + 3 iptal + n2 onayı)');

select ct.login('m1');
select lives_ok(
  $$select public.book_class(ct.id('n_ns'), ct.id('k_ns'))$$,
  'm1 gelmeyeceği derse rezervasyon yaptı');

reset role;
update public.classes
set starts_at = now() - interval '2 hours', ends_at = now() - interval '1 hour'
where id = ct.id('n_ns');

select ct.login('admin');
select lives_ok(
  $$select public.admin_set_no_show(ct.res('k_ns'))$$,
  'Yönetici gelmedi işaretledi');

reset role;
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m1')),
  8, 'B-02: gelmedi işareti bildirim üretmez (yalnızca n_ns onayı eklendi)');

-- ---------------------------------------------------------------------------
-- B-03 / Y-04: bildirimleri yalnızca sahibi görür; istemci değiştiremez
-- ---------------------------------------------------------------------------
select ct.login('m2');
select is(
  (select count(*)::int from public.notifications where user_id = ct.id('m1')),
  0, 'Y-04: üye başka üyenin bildirimlerini göremez');

select ct.login('m1');
select is(
  (select count(*)::int from public.notifications),
  8, 'B-03: üye kendi bildirimlerini görür');
select throws_ok(
  $$update public.notifications set status = 'sent'$$,
  '42501', NULL, 'B-03: üye bildirim durumunu değiştiremez');
select throws_ok(
  $$select * from public.claim_notifications(10)$$,
  '42501', NULL, 'B-03: kuyruk fonksiyonu istemciye kapalıdır (claim)');
select throws_ok(
  $$select public.complete_notification(ct.id('herhangi_bildirim'), true)$$,
  '42501', NULL, 'B-03: kuyruk fonksiyonu istemciye kapalıdır (complete)');

-- ---------------------------------------------------------------------------
-- Zamanlanmış bildirimler: ders hatırlatması ve paket bitiş uyarısı
-- ---------------------------------------------------------------------------
select lives_ok(
  $$select public.book_class(ct.id('n_soon'), ct.id('k_soon'))$$,
  'm1 2,5 saat sonraki derse rezervasyon yaptı');

select ct.login('m2');
select lives_ok(
  $$select public.book_class(ct.id('n_2h'), ct.id('k_2h'))$$,
  'm2 tam 2 saat sonraki derse rezervasyon yaptı');
select lives_ok(
  $$select public.book_class(ct.id('n_3h'), ct.id('k_3h'))$$,
  'm2 tam 3 saat sonraki derse rezervasyon yaptı');

reset role;
update public.member_packages set ends_at = now() + interval '2 days'
where id = ct.pkg('k_pkg_m2');

select ok(
  (select private.enqueue_scheduled_notifications()) >= 3,
  'Zamanlanmış görev en az 2 hatırlatma + 1 paket uyarısı üretti');
select is(
  (select private.enqueue_scheduled_notifications()),
  0, 'B-02: görev yeniden çalışınca aynı bildirimler tekrar üretilmez');
select is(
  (select array_agg(dedupe_key order by dedupe_key) from public.notifications
   where kind = 'class_reminder' and user_id in (ct.id('m1'), ct.id('m2'))),
  (select array_agg(k order by k)
   from unnest(array['class_reminder:' || ct.res('k_soon'),
                     'class_reminder:' || ct.res('k_3h')]) k),
  'B-01: hatırlatma yalnızca 2-3 saat sonraki dersler için (tam 2 saat hariç, tam 3 saat dahil)');
select is(
  (select count(*)::int from public.notifications
   where kind = 'package_expiring' and user_id = ct.id('m2')
     and payload ->> 'package_id' = ct.pkg('k_pkg_m2')::text),
  1, 'B-01: bitişine 3 günden az kalan paket için tek uyarı');
select is(
  (select count(*)::int from public.notifications
   where kind = 'package_expiring' and user_id = ct.id('m1')),
  0, 'B-01: bitişine 3 günden fazla kalan paket için uyarı yok');

-- ---------------------------------------------------------------------------
-- B-03: gönderici kuyruğu (service_role / Edge Function tarafı)
-- ---------------------------------------------------------------------------
select lives_ok(
  $$select count(*) from public.claim_notifications(500)$$,
  'Gönderici bekleyen bildirimleri sahiplenir');
select is(
  (select count(*)::int from public.notifications
   where user_id in (ct.id('m1'), ct.id('m2'))
     and (claimed_at is null or attempts <> 1)),
  0, 'B-03: sahiplenilen bildirimlerin deneme sayısı 1 oldu');
select is(
  (select count(*)::int from public.claim_notifications(500) c
   where c.user_id in (ct.id('m1'), ct.id('m2'))),
  0, 'B-02: sahiplenilmiş bildirim ikinci çağrıya verilmez');

select lives_ok(
  $$select public.complete_notification(
      (select id from public.notifications
       where dedupe_key = 'class_reminder:' || ct.res('k_soon')), true)$$,
  'Gönderici başarılı gönderimi bildirir');
select ok(
  (select status = 'sent' and sent_at is not null and error is null
   from public.notifications
   where dedupe_key = 'class_reminder:' || ct.res('k_soon')),
  'B-03: başarılı gönderim sent olarak saklanır');

select lives_ok(
  $$select public.complete_notification(
      (select id from public.notifications
       where dedupe_key = 'booking_confirmed:' || ct.res('k_soon')), false, 'token yok')$$,
  'Gönderici başarısız gönderimi bildirir');
select ok(
  (select status = 'pending' and claimed_at is null and error = 'token yok'
   from public.notifications
   where dedupe_key = 'booking_confirmed:' || ct.res('k_soon')),
  'B-03: ilk başarısızlıkta bildirim yeniden denenmek üzere bekler');

update public.notifications set attempts = 3
where dedupe_key = 'booking_confirmed:' || ct.res('k_soon');

select lives_ok(
  $$select public.complete_notification(
      (select id from public.notifications
       where dedupe_key = 'booking_confirmed:' || ct.res('k_soon')), false, 'token yok')$$,
  'Gönderici üçüncü başarısızlığı bildirir');
select ok(
  (select status = 'failed' and error = 'token yok'
   from public.notifications
   where dedupe_key = 'booking_confirmed:' || ct.res('k_soon')),
  'B-03: üç denemeden sonra failed olarak saklanır');

select lives_ok(
  $$select public.complete_notification(
      (select id from public.notifications
       where dedupe_key = 'class_reminder:' || ct.res('k_soon')), false, 'geç yanıt')$$,
  'Gönderilmiş bildirim için geç gelen başarısızlık yanıtı hata vermez');
select is(
  (select status::text from public.notifications
   where dedupe_key = 'class_reminder:' || ct.res('k_soon')),
  'sent', 'B-02: gönderilmiş bildirim yeniden kuyruğa dönmez');

select * from finish();
rollback;
