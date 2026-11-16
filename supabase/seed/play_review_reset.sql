-- Casper Training Studio — TAM SIFIRLAMA + Google Play inceleme/pilot demo verisi (16.11.2026)
--
-- DİKKAT: GERİ ALINAMAZ. Tüm kullanıcıları (yöneticiler dahil), dersleri, rezervasyonları,
-- paketleri, cüzdanları, satışları, programları, ölçümleri, referansları, protokolleri ve
-- işlem geçmişini siler. Kategoriler, paket tanımları ve ürünler KALIR.
--
--   supabase db query --remote --yes -f supabase/seed/play_review_reset.sql
--
-- Hesaplar (hepsinin şifresi 1234):
--   yonetici@casper.test   Demo Yönetici   yönetici
--   egitmen1@casper.test   Ayşe Yılmaz     eğitmen
--   egitmen2@casper.test   Mert Kaya       eğitmen
--   uye1@casper.test       Deniz Arslan    üye  ← Google inceleme hesabı
--       Atletik Performans Grup 12 ders + Özel Ders 8 ders, cüzdan 500 TL (1 Protein Bar alındı),
--       3 gelecek rezervasyon, antrenman programı, 2 ölçüm, sağlık rızası var
--   uye2@casper.test       Ece Demir       üye  Atletik Performans Grup 8 ders, 1 rezervasyon, cüzdan 250 TL
--   uye3@casper.test       Can Öztürk      üye  paketi yok (paketsiz akış), cüzdan 0
--
-- Dersler: yarından itibaren 14 gün, İstanbul saatiyle
--   Atletik Performans Grup  Pzt/Çar/Cum 18:30 (Ayşe), Sal/Per 19:00 (Mert), Cmt 10:00 (Ayşe)
--   Özel Ders                hafta içi 10:00 (Mert), 17:00 (Ayşe)
--   Atletik Özel Ders        Sal/Per 11:00 (Ayşe)

begin;

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-review:' || p)::uuid $$;

-- Uygulamanın kendi RPC'leri bu kullanıcı adına çalışsın (auth.uid())
create function pg_temp.as_user(p text) returns void language sql as
$$ select set_config('request.jwt.claims',
     json_build_object('sub', pg_temp.sid(p), 'role', 'authenticated')::text, true) $$;

-- ---------------------------------------------------------------------------
-- 1) Temizlik. Tablolar tek tek adlandırıldı: listede olmayan bağlı bir tablo varsa
--    TRUNCATE hata verir ve tüm dosya geri alınır (sessiz veri kaybı olmaz).
-- ---------------------------------------------------------------------------
truncate table
  public.audit_log,
  public.account_deletion_requests,
  public.body_measurements,
  public.workout_program_items,
  public.workout_programs,
  public.credit_ledger,
  public.package_freezes,
  public.reservations,
  public.classes,
  public.member_packages,
  public.wallet_ledger,
  public.sales,
  public.wallets,
  public.notifications,
  public.device_tokens,
  public.consents,
  public.referrals,
  public.profiles,
  public.protocols;
delete from auth.users;

-- ---------------------------------------------------------------------------
-- 2) Hesaplar (profil, cüzdan ve KVKK/sağlık onayı kayıt tetikleyicisiyle oluşur)
-- ---------------------------------------------------------------------------
with u(handle, full_name, health) as (values
  ('yonetici', 'Demo Yönetici', false),
  ('egitmen1', 'Ayşe Yılmaz',   false),
  ('egitmen2', 'Mert Kaya',     false),
  ('uye1',     'Deniz Arslan',  true),
  ('uye2',     'Ece Demir',     true),
  ('uye3',     'Can Öztürk',    false)
)
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
   confirmation_token, recovery_token, email_change_token_new, email_change,
   email_change_token_current, phone_change, phone_change_token, reauthentication_token,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', pg_temp.sid(handle), 'authenticated',
       'authenticated', handle || '@casper.test',
       extensions.crypt('1234', extensions.gen_salt('bf')), now(),
       '', '', '', '', '', '', '', '',
       '{"provider":"email","providers":["email"]}'::jsonb,
       jsonb_build_object('full_name', full_name, 'kvkk_accepted', 'true',
                          'kvkk_version', '2026-11-v4')
         || case when health then jsonb_build_object('health_consent', 'true',
                                                     'health_version', '2026-11-v1')
                 else '{}'::jsonb end,
       now(), now()
from u;

insert into auth.identities
  (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u;

update public.profiles set role = 'admin' where id = pg_temp.sid('yonetici');
update public.profiles set role = 'trainer' where id in (pg_temp.sid('egitmen1'), pg_temp.sid('egitmen2'));
update public.profiles set birth_date = '1994-05-12', height_cm = 172, weight_kg = 68
where id = pg_temp.sid('uye1');

-- ---------------------------------------------------------------------------
-- 3) Paketler, cüzdan, dersler, rezervasyonlar (uygulamanın RPC'leriyle)
-- ---------------------------------------------------------------------------
do $seed$
declare
  c_group uuid := (select id from public.categories where name = 'Atletik Performans Grup');
  c_ozel  uuid := (select id from public.categories where name = 'Özel Ders');
  c_atl   uuid := (select id from public.categories where name = 'Atletik Özel Ders');
  v_ayse  uuid := pg_temp.sid('egitmen1');
  v_mert  uuid := pg_temp.sid('egitmen2');
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_day   date;
  v_dow   integer;
  v_cls   public.classes;
  v_u1_group uuid[] := '{}';
  v_u1_ozel  uuid[] := '{}';
begin
  if c_group is null or c_ozel is null or c_atl is null then
    raise exception 'Beklenen kategoriler bulunamadı (Atletik Performans Grup / Özel Ders / Atletik Özel Ders)';
  end if;

  perform pg_temp.as_user('yonetici');
  perform public.assign_package(pg_temp.sid('uye1'),
    (select id from public.package_definitions where category_id = c_group and session_count = 12 and is_active),
    gen_random_uuid());
  perform public.assign_package(pg_temp.sid('uye1'),
    (select id from public.package_definitions where category_id = c_ozel and session_count = 8 and is_active),
    gen_random_uuid());
  perform public.assign_package(pg_temp.sid('uye2'),
    (select id from public.package_definitions where category_id = c_group and session_count = 8 and is_active),
    gen_random_uuid());
  perform public.admin_wallet_topup(pg_temp.sid('uye1'), 560, gen_random_uuid(), 'Nakit yükleme');
  perform public.admin_wallet_topup(pg_temp.sid('uye2'), 250, gen_random_uuid(), 'Kartla yükleme');

  -- 14 günlük ders programı
  for i in 1..14 loop
    v_day := v_today + i;
    v_dow := extract(isodow from v_day);
    if v_dow in (1, 3, 5) then
      select * into v_cls from public.create_class(c_group, 'group',
        (v_day + time '18:30') at time zone 'Europe/Istanbul', 60, null, v_ayse);
      if array_length(v_u1_group, 1) is null or array_length(v_u1_group, 1) < 2 then
        v_u1_group := v_u1_group || v_cls.id;
      end if;
    elsif v_dow in (2, 4) then
      perform public.create_class(c_group, 'group',
        (v_day + time '19:00') at time zone 'Europe/Istanbul', 60, null, v_mert);
      perform public.create_class(c_atl, 'individual',
        (v_day + time '11:00') at time zone 'Europe/Istanbul', 60, null, v_ayse);
    elsif v_dow = 6 then
      perform public.create_class(c_group, 'group',
        (v_day + time '10:00') at time zone 'Europe/Istanbul', 75, null, v_ayse);
    end if;
    if v_dow between 1 and 5 then
      select * into v_cls from public.create_class(c_ozel, 'individual',
        (v_day + time '10:00') at time zone 'Europe/Istanbul', 60, null, v_mert);
      if array_length(v_u1_ozel, 1) is null then
        v_u1_ozel := v_u1_ozel || v_cls.id;
      end if;
      perform public.create_class(c_ozel, 'individual',
        (v_day + time '17:00') at time zone 'Europe/Istanbul', 60, null, v_ayse);
    end if;
  end loop;

  -- Rezervasyonlar (üye kendi adına)
  perform pg_temp.as_user('uye1');
  perform public.book_class(v_u1_group[1], gen_random_uuid());
  perform public.book_class(v_u1_group[2], gen_random_uuid());
  perform public.book_class(v_u1_ozel[1], gen_random_uuid());
  perform pg_temp.as_user('uye2');
  perform public.book_class(v_u1_group[1], gen_random_uuid());

  -- Eğitmen satışı, program ve ölçümler
  perform pg_temp.as_user('egitmen1');
  perform public.sell_product(pg_temp.sid('uye1'),
    (select id from public.products where name = 'Protein Bar' and is_active), 1, gen_random_uuid());
  perform public.save_workout_program(pg_temp.sid('uye1'),
    'Temel Kuvvet — 4 Hafta', 'Genel kuvvet ve duruş',
    'Her setten önce 5 dk ısınma. Ağrı olursa bırak, eğitmene haber ver.',
    jsonb_build_array(
      jsonb_build_object('day_label', 'Gün 1', 'exercise', 'Goblet Squat', 'sets', 3, 'reps', '12', 'rest_seconds', 60),
      jsonb_build_object('day_label', 'Gün 1', 'exercise', 'Şınav', 'sets', 3, 'reps', '10', 'rest_seconds', 60),
      jsonb_build_object('day_label', 'Gün 1', 'exercise', 'Plank', 'sets', 3, 'reps', '40 sn', 'rest_seconds', 45),
      jsonb_build_object('day_label', 'Gün 2', 'exercise', 'Romanian Deadlift', 'sets', 3, 'reps', '10', 'rest_seconds', 90),
      jsonb_build_object('day_label', 'Gün 2', 'exercise', 'Lat Pulldown', 'sets', 3, 'reps', '12', 'rest_seconds', 60),
      jsonb_build_object('day_label', 'Gün 2', 'exercise', 'Walking Lunge', 'sets', 3, 'reps', '10+10', 'rest_seconds', 60)));
  perform public.add_body_measurement(pg_temp.sid('uye1'), v_today - 21,
    70.4, 27.5, 28.1, 78, 99, 92, 29, 56, 'Başlangıç ölçümü');
  perform public.add_body_measurement(pg_temp.sid('uye1'), v_today,
    68.9, 26.2, 28.6, 76, 98, 92, 29.5, 55.5, '3. hafta');

  perform set_config('request.jwt.claims', '', true);
end
$seed$;

-- ---------------------------------------------------------------------------
-- Özet
-- ---------------------------------------------------------------------------
select
  (select string_agg(u.email || ' (' || p.role::text || ')', ', ' order by p.role, u.email)
     from auth.users u join public.profiles p on p.id = u.id) as hesaplar,
  (select count(*) from public.classes) as ders,
  (select count(*) from public.reservations where status = 'booked') as rezervasyon,
  (select count(*) from public.member_packages where status = 'active') as aktif_paket,
  (select string_agg(round(balance)::text, '/') from public.wallets w
     join auth.users u on u.id = w.member_id where u.email like 'uye%') as cuzdanlar;

commit;
