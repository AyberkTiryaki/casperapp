-- Casper Training Studio — pgTAP: kurum protokolleri ve herkese açık fiyat listesi
-- Kurallar: PR-01 .. PR-12
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.

begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

create schema ct;
grant usage on schema ct to authenticated, anon;

create function ct.id(p_name text) returns uuid
language sql immutable as $f$
  select md5('casper-pgtap:' || p_name)::uuid
$f$;

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

create function ct.login(p_name text) returns void
language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', ct.id(p_name), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end
$f$;

create function ct.anon() returns void
language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('role', 'anon', true);
end
$f$;

grant execute on all functions in schema ct to authenticated, anon;

do $do$
begin
  perform ct.make_user('r_admin', 'admin');
  perform ct.make_user('r_trainer', 'trainer');
  perform ct.make_user('r_m1');   -- protokollü üye
  perform ct.make_user('r_m2');   -- m1'in getirdiği üye
  perform ct.make_user('r_m3');   -- protokolsüz üye
end
$do$;

insert into public.categories (id, name) values
  (ct.id('r_cat'), 'pgTAP Protokol Kategori'),
  (ct.id('r_cat_off'), 'pgTAP Pasif Kategori');
update public.categories set is_active = false where id = ct.id('r_cat_off');
insert into public.package_definitions
  (id, category_id, name, session_count, validity_days, price) values
  (ct.id('r_def8'), ct.id('r_cat'), 'pgTAP 8 Ders', 8, 30, 1000),
  (ct.id('r_def12'), ct.id('r_cat'), 'pgTAP 12 Ders', 12, 30, 1400),
  (ct.id('r_def_off'), ct.id('r_cat_off'), 'pgTAP Gizli', 8, 30, 500);

-- ---------------------------------------------------------------------------
-- Protokol tanımı: yalnızca yönetici (PR-01, PR-02)
-- ---------------------------------------------------------------------------
select ct.login('r_admin');
select lives_ok(
  $$insert into public.protocols (id, name, discount_percent)
    values (ct.id('pr_x'), 'pgTAP X Sendikası', 15)$$,
  'PR-01: yönetici protokol ekler');
select throws_ok(
  $$insert into public.protocols (name, discount_percent) values ('pgTAP Fazla', 60)$$,
  '23514', NULL, 'PR-01: oran %50 üstü olamaz');
insert into public.protocols (id, name, discount_percent, valid_until) values
  (ct.id('pr_eski'), 'pgTAP Süresi Dolmuş', 20, current_date - 10),
  (ct.id('pr_tam'), 'pgTAP Büyük İndirim', 50, null);
insert into public.protocols (id, name, discount_percent, is_active)
  values (ct.id('pr_pasif'), 'pgTAP Pasif', 10, false);
reset role;

select ct.login('r_trainer');
select throws_ok(
  $$insert into public.protocols (name, discount_percent) values ('pgTAP Eğitmen', 10)$$,
  '42501', NULL, 'PR-02: eğitmen protokol ekleyemez');
select is((select count(*)::int from public.protocols), 0,
  'PR-02: eğitmen protokol listesini göremez');
reset role;

-- ---------------------------------------------------------------------------
-- Üyeyi protokole bağlama (PR-03, PR-04)
-- ---------------------------------------------------------------------------
select ct.login('r_m1');
select throws_ok(
  $$select public.admin_set_member_protocol(ct.id('r_m1'), ct.id('pr_x'))$$,
  '42501', 'FORBIDDEN', 'PR-03: üye kendini protokole bağlayamaz');
select throws_ok(
  $$update public.profiles set protocol_id = ct.id('pr_x') where id = ct.id('r_m1')$$,
  '42501', NULL, 'PR-03: üye protocol_id sütununu doğrudan değiştiremez');
reset role;

select ct.login('r_admin');
select throws_ok(
  $$select public.admin_set_member_protocol(ct.id('r_m1'), ct.id('pr_eski'))$$,
  'P0002', 'PROTOCOL_NOT_FOUND', 'PR-04: süresi dolmuş protokole bağlanamaz');
select throws_ok(
  $$select public.admin_set_member_protocol(ct.id('r_m1'), ct.id('pr_pasif'))$$,
  'P0002', 'PROTOCOL_NOT_FOUND', 'PR-04: pasif protokole bağlanamaz');
select throws_ok(
  $$select public.admin_set_member_protocol(ct.id('r_trainer'), ct.id('pr_x'))$$,
  'P0001', 'MEMBER_NOT_ELIGIBLE', 'PR-04: yalnızca üye bağlanabilir');
select lives_ok(
  $$select public.admin_set_member_protocol(ct.id('r_m1'), ct.id('pr_x'))$$,
  'PR-03: yönetici üyeyi protokole bağlar');
reset role;
select is((select protocol_id from public.profiles where id = ct.id('r_m1')), ct.id('pr_x'),
  'PR-03: bağlantı kaydedilir');
select is(
  (select count(*)::int from public.audit_log
   where action = 'set_member_protocol' and entity_id = ct.id('r_m1')::text),
  1, 'PR-03: denetim kaydı yazılır');

select ct.login('r_m1');
select is((select array_agg(name) from public.protocols), array['pgTAP X Sendikası'],
  'PR-02: üye yalnızca kendi protokolünü görür');
reset role;

-- ---------------------------------------------------------------------------
-- Paket atamasında indirim (PR-05 .. PR-07)
-- ---------------------------------------------------------------------------
select ct.login('r_admin');
select is(
  (select row(discount_percent, protocol_discount_percent, protocol_id, price_paid)::text
   from public.assign_package(ct.id('r_m1'), ct.id('r_def8'), ct.id('k_r_m1_8'))),
  row(15, 15, ct.id('pr_x'), 850.00::numeric(12,2))::text,
  'PR-05: protokol indirimi otomatik uygulanır (%15 → 850 TL)');
select is(
  (select row(discount_percent, protocol_discount_percent, price_paid)::text
   from public.assign_package(ct.id('r_m3'), ct.id('r_def8'), ct.id('k_r_m3_8'))),
  row(0, 0, 1000.00::numeric(12,2))::text,
  'PR-05: protokolsüz üye liste fiyatını öder');

-- m1, m2'yi getirdi; m2'nin aktif paketi olunca m1'in referans hakkı %5
reset role;
insert into public.referrals (referrer_id, referred_id, code_used, status)
values (ct.id('r_m1'), ct.id('r_m2'), 'PGTAP', 'approved');
select ct.login('r_admin');
select public.assign_package(ct.id('r_m2'), ct.id('r_def8'), ct.id('k_r_m2_8'));
select is(
  (select row(discount_percent, protocol_discount_percent, price_paid)::text
   from public.assign_package(ct.id('r_m1'), ct.id('r_def8'), ct.id('k_r_m1_8b'), true, 5)),
  row(20, 15, 800.00::numeric(12,2))::text,
  'PR-05: referans ve protokol indirimi toplanır (%5 + %15 = %20)');
select throws_ok(
  $$select public.assign_package(ct.id('r_m1'), ct.id('r_def12'), ct.id('k_r_m1_12'), false, 10)$$,
  'P0001', 'DISCOUNT_EXCEEDS_ENTITLEMENT', 'PR-05: referans payı hak edileni aşamaz');

select public.admin_set_member_protocol(ct.id('r_m1'), ct.id('pr_tam'));
select is(
  (select row(discount_percent, protocol_discount_percent, price_paid)::text
   from public.assign_package(ct.id('r_m1'), ct.id('r_def12'), ct.id('k_r_m1_12b'), true, 5)),
  row(50, 50, 700.00::numeric(12,2))::text,
  'PR-06: toplam indirim en fazla %50 (5 + 50 → 50)');

-- Protokol sonradan değişse de atanmış paket aynı kalır
update public.protocols set discount_percent = 30 where id = ct.id('pr_x');
reset role;
select is(
  (select discount_percent from public.member_packages
   where idempotency_key = ct.id('k_r_m1_8b')),
  20, 'PR-07: atanmış paketin oranı protokol değişiminden etkilenmez');

-- ---------------------------------------------------------------------------
-- Herkese açık fiyat listesi (PR-09 .. PR-11)
-- ---------------------------------------------------------------------------
select ct.anon();
select ok(
  (select public.public_price_list() -> 'categories' @> jsonb_build_array(
     jsonb_build_object('name', 'pgTAP Protokol Kategori'))),
  'PR-09: giriş yapmamış kişi aktif kategorileri görür');
select ok(
  not (public.public_price_list()::text like '%pgTAP Gizli%'
       or public.public_price_list()::text like '%pgTAP Pasif Kategori%'),
  'PR-10: pasif kategori ve paketleri listede yok');
select ok(
  (select array_agg(e ->> 'name' order by e ->> 'name')
   from jsonb_array_elements(public.public_price_list() -> 'protocols') e
   where e ->> 'name' like 'pgTAP%')
  = array['pgTAP Büyük İndirim', 'pgTAP X Sendikası'],
  'PR-11: yalnızca geçerli protokoller listelenir (pasif ve süresi dolmuş yok)');
reset role;

select * from finish();
rollback;
