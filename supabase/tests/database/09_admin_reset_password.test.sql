-- Casper Training Studio — pgTAP: yöneticinin şifre sıfırlaması
-- Kural: Y-11
-- Dosya tek transaction içinde çalışır ve rollback ile biter; kalıcı veri bırakmaz.

begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

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
  perform ct.make_user('p_admin', 'admin');
  perform ct.make_user('p_admin2', 'admin');
  perform ct.make_user('p_trainer', 'trainer');
  perform ct.make_user('p_member');
end
$do$;

-- Üyenin açık bir oturumu olsun
insert into auth.sessions (id, user_id, created_at, updated_at)
values (gen_random_uuid(), ct.id('p_member'), now(), now());

select ct.login('p_admin');
select lives_ok(
  $$select public.admin_reset_password(ct.id('p_member'), '4321')$$,
  'Y-11: yönetici üyenin şifresini sıfırlar');
reset role;
select ok(
  (select encrypted_password = extensions.crypt('4321', encrypted_password)
   from auth.users where id = ct.id('p_member')),
  'Y-11: yeni şifre kaydedilir (bcrypt)');
select is(
  (select count(*)::int from auth.sessions where user_id = ct.id('p_member')),
  0, 'Y-11: üyenin açık oturumları kapatılır');
select is(
  (select count(*)::int from public.audit_log
   where action = 'admin_reset_password' and entity_id = ct.id('p_member')::text
     and actor_id = ct.id('p_admin')),
  1, 'Y-11: işlem denetim kaydına yazılır');
select ok(
  (select not (details::text ilike '%4321%') from public.audit_log
   where action = 'admin_reset_password' and entity_id = ct.id('p_member')::text),
  'Y-11: denetim kaydında şifre yer almaz');

select ct.login('p_admin');
select lives_ok(
  $$select public.admin_reset_password(ct.id('p_trainer'), 'egitmen1')$$,
  'Y-11: yönetici eğitmenin şifresini sıfırlar');
select throws_ok(
  $$select public.admin_reset_password(ct.id('p_admin2'), '1234')$$,
  '42501', 'FORBIDDEN', 'Y-11: başka yöneticinin şifresi sıfırlanamaz');
select throws_ok(
  $$select public.admin_reset_password(ct.id('p_admin'), '1234')$$,
  '42501', 'FORBIDDEN', 'Y-11: yönetici kendi şifresini bununla değiştiremez');
select throws_ok(
  $$select public.admin_reset_password(ct.id('p_member'), '123')$$,
  'P0001', 'WEAK_PASSWORD', 'Y-11: şifre en az 4 karakter');
select throws_ok(
  $$select public.admin_reset_password(gen_random_uuid(), '1234')$$,
  'P0002', 'USER_NOT_FOUND', 'Y-11: olmayan kullanıcı');

select ct.login('p_trainer');
select throws_ok(
  $$select public.admin_reset_password(ct.id('p_member'), '1234')$$,
  '42501', 'FORBIDDEN', 'Y-11: eğitmen şifre sıfırlayamaz');

reset role;
set local role anon;
select throws_ok(
  $$select public.admin_reset_password(ct.id('p_member'), '1234')$$,
  '42501', NULL, 'Y-08: anon çağıramaz');
reset role;

select * from finish();
rollback;
