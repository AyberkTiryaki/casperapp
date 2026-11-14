-- Casper Training Studio — pgTAP: sağlık verisi açık rızası (KVKK md. 6)
-- Kurallar: K-09..K-12
-- Çalıştırma: supabase test db veya python supabase/tests/run_remote.py (bkz. docs/TESTING.md)
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

-- p_health: kayıt sırasında sağlık verisi rızası verildi mi
create function ct.make_user(p_name text, p_role public.user_role default 'member',
                             p_health boolean default false)
returns uuid language plpgsql as $f$
declare
  v_id uuid := ct.id(p_name);
  v_meta jsonb := jsonb_build_object('full_name', 'Test ' || p_name,
                    'kvkk_accepted', 'true', 'kvkk_version', 'pgtap-1');
begin
  if p_health then
    v_meta := v_meta || jsonb_build_object('health_consent', 'true',
                                           'health_version', 'pgtap-h1');
  end if;
  insert into auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
     raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
    ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
     'pgtap-' || v_id || '@example.invalid', '', now(),
     '{"provider":"email","providers":["email"]}'::jsonb, v_meta, now(), now());
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

grant execute on all functions in schema ct to authenticated, anon;

do $do$
begin
  perform ct.make_user('h_admin', 'admin');
  perform ct.make_user('h_trainer', 'trainer');
  perform ct.make_user('h_yes', 'member', true);   -- kayıtta rıza verdi
  perform ct.make_user('h_no');                    -- rıza vermedi
end
$do$;

-- ---------------------------------------------------------------------------
-- K-09: kayıt sırasında rıza isteğe bağlıdır ve ayrı kaydedilir
-- ---------------------------------------------------------------------------
select is(
  (select text_version from public.consents
   where user_id = ct.id('h_yes') and consent_type = 'health' and revoked_at is null),
  'pgtap-h1', 'K-09: kayıtta verilen sağlık rızası sürümüyle kaydedilir');
select is(
  (select count(*)::int from public.consents
   where user_id = ct.id('h_no') and consent_type = 'health'),
  0, 'K-09: rıza verilmezse sağlık rızası kaydı oluşmaz');
select is(
  (select count(*)::int from public.consents
   where user_id = ct.id('h_no') and consent_type = 'kvkk'),
  1, 'K-09: aydınlatma onayı sağlık rızasından bağımsız kaydedilir');

-- ---------------------------------------------------------------------------
-- K-10: rızası olmayan üyeye ölçüm yazılamaz
-- ---------------------------------------------------------------------------
select ct.login('h_no');
select is(public.member_health_consent(ct.id('h_no')), false,
  'K-10: üye kendi rıza durumunu görür (yok)');
select throws_ok(
  $$select public.add_body_measurement(ct.id('h_no'), null, 70)$$,
  'P0001', 'HEALTH_CONSENT_REQUIRED', 'K-10: rızası olmayan üye kendine ölçüm ekleyemez');
select throws_ok(
  $$select public.member_health_consent(ct.id('h_yes'))$$,
  '42501', 'FORBIDDEN', 'K-10: üye başka üyenin rıza durumunu soramaz');

select ct.login('h_admin');
select throws_ok(
  $$select public.add_body_measurement(ct.id('h_no'), null, 70)$$,
  'P0001', 'HEALTH_CONSENT_REQUIRED', 'K-10: yönetici de rızası olmayan üyeye ölçüm ekleyemez');
select is(public.member_health_consent(ct.id('h_no')), false,
  'K-10: yönetici üyenin rıza durumunu görür');

select ct.login('h_trainer');
select throws_ok(
  $$select public.member_health_consent(ct.id('h_no'))$$,
  '42501', 'FORBIDDEN', 'K-10: eğitmen kendi üyesi olmayanın rıza durumunu soramaz');

-- ---------------------------------------------------------------------------
-- K-11: rıza sonradan verilebilir
-- ---------------------------------------------------------------------------
select ct.login('h_no');
select throws_ok(
  $$select public.set_health_consent(true, '  ')$$,
  'P0001', 'INVALID_VERSION', 'K-11: sürümsüz rıza verilemez');
select is(public.set_health_consent(true, 'pgtap-h2'), true,
  'K-11: üye rızayı sonradan verir');
select lives_ok(
  $$select public.add_body_measurement(ct.id('h_no'), null, 70)$$,
  'K-11: rıza verildikten sonra ölçüm eklenir');

-- ---------------------------------------------------------------------------
-- K-12: rıza geri alınınca ölçümler silinir
-- ---------------------------------------------------------------------------
select ct.login('h_admin');
select lives_ok(
  $$select public.add_body_measurement(ct.id('h_yes'), null, 65)$$,
  'K-12: rızası olan üyeye yönetici ölçüm ekler');

select ct.login('h_yes');
select lives_ok(
  $$select public.add_body_measurement(ct.id('h_yes'), null, 66)$$,
  'K-12: rızası olan üye kendine ölçüm ekler');
select is(public.set_health_consent(false), false, 'K-12: üye rızasını geri alır');

reset role;
select is(
  (select count(*)::int from public.body_measurements where member_id = ct.id('h_yes')),
  0, 'K-12: rıza geri alınınca üyenin tüm ölçümleri silinir');
select isnt(
  (select revoked_at from public.consents
   where user_id = ct.id('h_yes') and consent_type = 'health'),
  null, 'K-12: rıza kaydı silinmez, geri alma zamanı yazılır');
select is(
  (select (details ->> 'deleted_measurements')::int from public.audit_log
   where action = 'health_consent_revoke' and entity_id = ct.id('h_yes')::text),
  2, 'K-12: geri alma ve silinen ölçüm sayısı denetim kaydına yazılır');

select ct.login('h_yes');
select throws_ok(
  $$select public.add_body_measurement(ct.id('h_yes'), null, 66)$$,
  'P0001', 'HEALTH_CONSENT_REQUIRED', 'K-12: geri alınan rızayla ölçüm eklenemez');
select is(public.set_health_consent(true, 'pgtap-h1'), true,
  'K-11: aynı sürüm yeniden onaylanabilir');

-- ---------------------------------------------------------------------------
-- Y-08: anon erişemez
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select throws_ok(
  $$select public.set_health_consent(true, 'x')$$,
  '42501', NULL, 'Y-08: anon set_health_consent çağıramaz');
select throws_ok(
  $$select public.member_health_consent(ct.id('h_no'))$$,
  '42501', NULL, 'Y-08: anon member_health_consent çağıramaz');
reset role;

select * from finish();
rollback;
