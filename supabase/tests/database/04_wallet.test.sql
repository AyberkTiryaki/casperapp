-- Casper Training Studio — pgTAP: Cüzdan ve ürün satışı
-- Kurallar: C-01..C-09
-- Çalıştırma: supabase test db (yalnızca yerel yığın; bkz. docs/TESTING.md)
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.
-- now() transaction boyunca sabit olduğundan zaman sınırları tam ölçülür.

begin;

create extension if not exists pgtap with schema extensions;

select plan(67);

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
  perform ct.make_user('w1');
  perform ct.make_user('w2');
end
$do$;

insert into public.products (id, name, price, is_active) values
  (ct.id('p30'),   'pgTAP Protein Bar', 30.00, true),
  (ct.id('p_off'), 'pgTAP Pasif Ürün',  10.00, false);

select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  0.00::numeric, 'Kayıt olan üyenin cüzdanı 0 bakiyeyle açılır');

-- ---------------------------------------------------------------------------
-- C-01: bakiyeyi yalnızca yönetici yükler
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 100, ct.id('k_top_trainer'))$$,
  '42501', 'FORBIDDEN', 'C-01/Y-05: eğitmen bakiye yükleyemez');

select ct.login('w1');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 100, ct.id('k_top_uye'))$$,
  '42501', 'FORBIDDEN', 'C-01: üye kendi cüzdanına bakiye yükleyemez');

select ct.login('admin');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 0, ct.id('k_top_x1'))$$,
  'P0001', 'INVALID_AMOUNT', 'C-01: tutar 0 olamaz');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), -5, ct.id('k_top_x2'))$$,
  'P0001', 'INVALID_AMOUNT', 'C-01: tutar eksi olamaz');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 10.005, ct.id('k_top_x3'))$$,
  'P0001', 'INVALID_AMOUNT', 'C-01: tutar en fazla 2 ondalıklı olabilir');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 1000000.01, ct.id('k_top_x4'))$$,
  'P0001', 'INVALID_AMOUNT', 'C-01: tek yükleme üst sınırı aşılamaz');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 100, null)$$,
  'P0001', 'IDEMPOTENCY_KEY_REQUIRED', 'C-06: anahtarsız yükleme reddedilir');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('yok_boyle_kullanici'), 100, ct.id('k_top_x5'))$$,
  'P0002', 'USER_NOT_FOUND', 'Olmayan kullanıcıya yükleme yapılamaz');
select is(
  (select balance_after
   from public.admin_wallet_topup(ct.id('w1'), 100, ct.id('k_top1'), 'Nakit')),
  100.00::numeric, 'C-01/C-07: yükleme hareketi işlem sonrası bakiyeyi içerir');

-- C-06: tekrarlanan yükleme
select is(
  (select id from public.admin_wallet_topup(ct.id('w1'), 100, ct.id('k_top1'))),
  ct.wl('k_top1'), 'C-06: aynı anahtarla yükleme aynı hareketi döndürür');
select throws_ok(
  $$select public.admin_wallet_topup(ct.id('w1'), 50, ct.id('k_top1'))$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'C-06: aynı anahtar farklı tutar için kullanılamaz');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  100.00::numeric, 'C-06: tekrarlanan yükleme bakiyeyi ikinci kez artırmadı');
select is(
  (select count(*)::int from public.wallet_ledger where member_id = ct.id('w1')),
  1, 'C-06/C-07: tek topup hareketi var');
select is(
  (select count(*)::int from public.audit_log
   where action = 'wallet_topup' and entity_id = ct.wl('k_top1')::text),
  1, 'Y-09: yükleme denetim kaydına yazılır');

-- ---------------------------------------------------------------------------
-- C-03, C-04: satış
-- ---------------------------------------------------------------------------
select ct.login('w1');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 1, ct.id('k_sale_uye'))$$,
  '42501', 'FORBIDDEN', 'C-03: üye satış yapamaz');

select ct.login('trainer');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 0, ct.id('k_sale_x1'))$$,
  'P0001', 'INVALID_QUANTITY', 'C-03: adet en az 1 olmalıdır');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 101, ct.id('k_sale_x2'))$$,
  'P0001', 'INVALID_QUANTITY', 'C-03: adet en fazla 100 olabilir');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p_off'), 1, ct.id('k_sale_x3'))$$,
  'P0002', 'PRODUCT_NOT_FOUND', 'Pasif ürün satılamaz');
select throws_ok(
  $$select public.sell_product(ct.id('admin'), ct.id('p30'), 1, ct.id('k_sale_x4'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'Satış yalnızca üyeye yapılır');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 1, null)$$,
  'P0001', 'IDEMPOTENCY_KEY_REQUIRED', 'C-06: anahtarsız satış reddedilir');
select is(
  (select total from public.sell_product(ct.id('w1'), ct.id('p30'), 2, ct.id('k_sale1'))),
  60.00::numeric, 'C-03: eğitmen satış yapar (2 x 30)');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  40.00::numeric, 'C-05: satış tutarı bakiyeden düşüldü (100 - 60)');
select ok(
  (select unit_price = 30 and quantity = 2 and seller_id = ct.id('trainer')
          and reversed_at is null
   from public.sales where id = ct.sale('k_sale1')),
  'C-04: satış anındaki birim fiyat satışa kopyalandı');
select ok(
  (select entry_type = 'purchase' and amount = -60 and balance_after = 40
          and sale_id = ct.sale('k_sale1') and created_by = ct.id('trainer')
   from public.wallet_ledger where id = ct.wl('k_sale1')),
  'C-07: purchase hareketi satışa bağlı ve işlem sonrası bakiyeyi içerir');

-- ---------------------------------------------------------------------------
-- C-06: tekrarlanan satış
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select is(
  (select id from public.sell_product(ct.id('w1'), ct.id('p30'), 2, ct.id('k_sale1'))),
  ct.sale('k_sale1'), 'C-06: aynı anahtarla satış aynı kaydı döndürür');
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 1, ct.id('k_sale1'))$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'C-06: aynı anahtar farklı adet için kullanılamaz');

reset role;
select is(
  (select count(*)::int from public.sales where member_id = ct.id('w1')),
  1, 'C-06: tek satış kaydı var');
select is(
  (select count(*)::int from public.wallet_ledger
   where member_id = ct.id('w1') and entry_type = 'purchase'),
  1, 'C-06: tek purchase hareketi var');
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  40.00::numeric, 'C-06: tekrarlanan satış bakiyeyi ikinci kez düşmedi');

-- ---------------------------------------------------------------------------
-- C-04: fiyat sunucuda işlem anındaki değerden alınır
-- ---------------------------------------------------------------------------
update public.products set price = 35.00 where id = ct.id('p30');

select ct.login('trainer');
select is(
  (select unit_price
   from public.sell_product(ct.id('w1'), ct.id('p30'), 1, ct.id('k_sale2'))),
  35.00::numeric, 'C-04: yeni satış güncel fiyattan yapılır');
select is(
  (select unit_price
   from public.sell_product(ct.id('w1'), ct.id('p30'), 2, ct.id('k_sale1'))),
  30.00::numeric, 'C-04: fiyat değişikliği eski satışı etkilemez');

-- ---------------------------------------------------------------------------
-- C-05: yetersiz bakiye
-- ---------------------------------------------------------------------------
select throws_ok(
  $$select public.sell_product(ct.id('w1'), ct.id('p30'), 1, ct.id('k_sale3'))$$,
  'P0001', 'INSUFFICIENT_BALANCE', 'C-05: bakiye yetersizse satış yapılmaz (5 < 35)');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  5.00::numeric, 'C-05: reddedilen satış bakiyeyi değiştirmedi (100 - 60 - 35)');
select is(
  (select count(*)::int from public.sales where idempotency_key = ct.id('k_sale3')),
  0, 'C-05: reddedilen satış kaydı oluşmadı');

-- Bakiye tam yetiyorsa satış yapılır ve bakiye 0 olur
select ct.login('admin');
select lives_ok(
  $$select public.admin_wallet_topup(ct.id('w2'), 35, ct.id('k_top_w2'))$$,
  'Hazırlık: w2 cüzdanına 35 yüklendi');
select is(
  (select total from public.sell_product(ct.id('w2'), ct.id('p30'), 1, ct.id('k_sale_w2'))),
  35.00::numeric, 'C-03: yönetici de satış yapabilir');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w2')),
  0.00::numeric, 'C-05: bakiye tam yetiyorsa satış yapılır, bakiye 0 olur');

-- ---------------------------------------------------------------------------
-- C-02: üye kendi bakiyesini ve hareketlerini görür
-- ---------------------------------------------------------------------------
select ct.login('w1');
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  5.00::numeric, 'C-02: üye kendi bakiyesini görür');
select is(
  (select count(*)::int from public.wallets),
  1, 'Y-04: üye yalnızca kendi cüzdan satırını görür');
select is(
  (select count(*)::int from public.wallet_ledger),
  3, 'C-02: üye kendi 3 hareketini görür (yükleme + 2 satış)');
select is(
  (select count(*)::int from public.wallet_ledger where member_id = ct.id('w2')),
  0, 'Y-04: üye başka üyenin cüzdan hareketini göremez');

-- ---------------------------------------------------------------------------
-- C-08: ters kayıt
-- ---------------------------------------------------------------------------
select ct.login('trainer');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_sale1'), ct.id('k_rev_trainer'))$$,
  '42501', 'FORBIDDEN', 'C-08/Y-05: eğitmen ters kayıt giremez');

select ct.login('admin');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(-1, ct.id('k_rev_x1'))$$,
  'P0002', 'ENTRY_NOT_FOUND', 'C-08: olmayan hareket ters çevrilemez');
select is(
  (select amount
   from public.admin_reverse_wallet_entry(ct.wl('k_sale1'), ct.id('k_rev1'), 'Yanlış ürün')),
  60.00::numeric, 'C-08: hatalı satış ters kayıtla düzeltilir (+60)');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  65.00::numeric, 'C-08: ters kayıtla bakiye geri geldi (5 + 60)');
select ok(
  (select reversed_at is not null and reversed_by = ct.id('admin')
   from public.sales where id = ct.sale('k_sale1')),
  'C-08: satış reversed_at ile işaretlendi');
select ok(
  (select entry_type = 'reversal' and reverses_entry_id = ct.wl('k_sale1')
          and sale_id = ct.sale('k_sale1') and balance_after = 65
   from public.wallet_ledger where id = ct.wl('k_rev1')),
  'C-08: ters kayıt özgün harekete ve satışa bağlı');
select is(
  (select count(*)::int from public.wallet_ledger where id = ct.wl('k_sale1')),
  1, 'C-08: hatalı hareket silinmedi');

select ct.login('admin');
select is(
  (select id from public.admin_reverse_wallet_entry(ct.wl('k_sale1'), ct.id('k_rev1'))),
  ct.wl('k_rev1'), 'C-06: tekrarlanan ters kayıt isteği aynı hareketi döndürür');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_sale1'), ct.id('k_rev2'))$$,
  'P0001', 'ALREADY_REVERSED', 'C-08: bir hareket en fazla bir kez ters çevrilir');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_rev1'), ct.id('k_rev3'))$$,
  'P0001', 'CANNOT_REVERSE_REVERSAL', 'C-08: ters kaydın tersi alınamaz');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_sale2'), ct.id('k_rev1'))$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'C-06: ters kayıt anahtarı başka hareket için kullanılamaz');

reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  65.00::numeric, 'C-08: reddedilen ters kayıtlar bakiyeyi değiştirmedi');
select is(
  (select count(*)::int from public.wallet_ledger
   where member_id = ct.id('w1') and entry_type = 'reversal'),
  1, 'C-08: tek ters kayıt var');

-- ---------------------------------------------------------------------------
-- C-09: ters kayıt bakiyeyi eksiye düşüremez
-- ---------------------------------------------------------------------------
select ct.login('admin');
select throws_ok(
  $$select public.admin_reverse_wallet_entry(ct.wl('k_top_w2'), ct.id('k_rev_w2'))$$,
  'P0001', 'INSUFFICIENT_BALANCE', 'C-09: harcanmış yüklemenin tersi bakiyeyi eksiye düşüreceği için yapılmaz');

-- ---------------------------------------------------------------------------
-- C-08: düzeltme hareketi
-- ---------------------------------------------------------------------------
select throws_ok(
  $$select public.admin_wallet_adjust(ct.id('w1'), -5, '  ', ct.id('k_adj_x1'))$$,
  'P0001', 'NOTE_REQUIRED', 'C-08: düzeltmede açıklama zorunludur');
select throws_ok(
  $$select public.admin_wallet_adjust(ct.id('w1'), 0, 'deneme', ct.id('k_adj_x2'))$$,
  'P0001', 'INVALID_AMOUNT', 'C-08: düzeltme tutarı 0 olamaz');
select throws_ok(
  $$select public.admin_wallet_adjust(ct.id('w1'), -65.01, 'deneme', ct.id('k_adj_x3'))$$,
  'P0001', 'INSUFFICIENT_BALANCE', 'C-05: düzeltme bakiyeyi eksiye düşüremez');
select is(
  (select balance_after
   from public.admin_wallet_adjust(ct.id('w1'), -5, 'Kasa farkı', ct.id('k_adj1'))),
  60.00::numeric, 'C-08: açıklamalı eksi düzeltme (65 - 5)');
select is(
  (select id
   from public.admin_wallet_adjust(ct.id('w1'), -5, 'Kasa farkı', ct.id('k_adj1'))),
  ct.wl('k_adj1'), 'C-06: tekrarlanan düzeltme aynı hareketi döndürür');

select ct.login('trainer');
select throws_ok(
  $$select public.admin_wallet_adjust(ct.id('w1'), 5, 'deneme', ct.id('k_adj_trainer'))$$,
  '42501', 'FORBIDDEN', 'C-08/Y-05: eğitmen düzeltme giremez');

-- ---------------------------------------------------------------------------
-- C-07: hareketler ile bakiye tutarlı
-- ---------------------------------------------------------------------------
reset role;
select is(
  (select balance from public.wallets where member_id = ct.id('w1')),
  60.00::numeric, 'C-07: son bakiye 60');
select is(
  (select sum(amount) from public.wallet_ledger where member_id = ct.id('w1')),
  60.00::numeric, 'C-07: w1 hareket toplamı bakiyeye eşit');
select is(
  (select sum(amount) from public.wallet_ledger where member_id = ct.id('w2')),
  0.00::numeric, 'C-07: w2 hareket toplamı bakiyeye eşit');
select is(
  (select count(*)::int
   from (select balance_after,
                sum(amount) over (partition by member_id order by id) as running
         from public.wallet_ledger
         where member_id in (ct.id('w1'), ct.id('w2'))) x
   where x.balance_after <> x.running),
  0, 'C-07: her hareketin balance_after değeri o ana kadarki toplamla aynı');
select is(
  (select count(*)::int from public.wallet_ledger
   where member_id in (ct.id('w1'), ct.id('w2')) and balance_after < 0),
  0, 'C-05: hiçbir hareketten sonra bakiye eksiye düşmedi');

select * from finish();
rollback;
