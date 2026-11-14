-- Casper Training Studio — deneme (pilot) verisi. YALNIZCA dev/pilot ortamı için.
-- NOT (14.11.2026): Pilates / Fonksiyonel / Yoga kategorileri kaldırıldı (remove_old_categories.sql).
-- Bu dosya yeniden çalıştırılırsa eski kategorileri geri getirir; güncel paketler packages_2026_11.sql.
--
-- Çalıştırma (proje kökünden):
--   supabase db query --remote --yes -f supabase/seed/demo.sql
-- Tekrar çalıştırılabilir: var olan kayıtlar atlanır, yalnızca eksikler eklenir.
-- Silmek için: supabase/seed/demo_cleanup.sql
--
-- Hesaplar (hepsinin şifresi 1234):
--   yonetici@casper.test                 yönetici
--   egitmen1..3@casper.test              eğitmen
--   uye1..6@casper.test                  üye
--     uye1  Pilates 8 ders, cüzdan 500 TL, yarınki Pilates dersine kayıtlı
--     uye2  Pilates 12 ders, cüzdan 200 TL, yarınki Pilates dersine kayıtlı
--     uye3  Fonksiyonel 8 ders
--     uye4  Fonksiyonel 16 ders, yarınki akşam dersine kayıtlı
--     uye5  paketi yok (paketsiz üye akışını denemek için)
--     uye6  Pilates 8 ders, cüzdan 0 TL

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-seed:' || p)::uuid $$;

-- ---------------------------------------------------------------------------
-- Kullanıcılar (profil, cüzdan ve KVKK onayı tetikleyiciyle oluşur)
-- ---------------------------------------------------------------------------
with u(handle, full_name, role) as (values
  ('yonetici', 'Deneme Yönetici', 'admin'),
  ('egitmen1', 'Ayşe Eğitmen',    'trainer'),
  ('egitmen2', 'Mert Eğitmen',    'trainer'),
  ('egitmen3', 'Selin Eğitmen',   'trainer'),
  ('uye1',     'Deniz Üye',       'member'),
  ('uye2',     'Ece Üye',         'member'),
  ('uye3',     'Can Üye',         'member'),
  ('uye4',     'Zeynep Üye',      'member'),
  ('uye5',     'Burak Üye',       'member'),
  ('uye6',     'Elif Üye',        'member')
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
                          'kvkk_version', '2026-11-v1'),
       now(), now()
from u
where not exists (select 1 from auth.users x where x.email = u.handle || '@casper.test');

insert into auth.identities
  (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u
where u.email like '%@casper.test'
  and not exists (select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email');

update public.profiles p set role = v.role::public.user_role
from (values ('yonetici', 'admin'), ('egitmen1', 'trainer'),
             ('egitmen2', 'trainer'), ('egitmen3', 'trainer')) v(handle, role)
where p.id = pg_temp.sid(v.handle) and p.role <> v.role::public.user_role;

-- Boy / kilo / doğum tarihi (yönetici kullanıcı listesinde görünür)
update public.profiles p set height_cm = v.h, weight_kg = v.w, birth_date = v.b::date
from (values
  ('uye1', 172, 68.5, '1992-04-12'), ('uye2', 165, 58.0, '1996-09-03'),
  ('uye3', 181, 82.0, '1988-01-27'), ('uye4', 168, 61.5, '1999-12-15'),
  ('uye5', 176, 90.0, '1985-06-30'), ('uye6', 160, 54.0, '2001-03-08')
) v(handle, h, w, b)
where p.id = pg_temp.sid(v.handle) and p.height_cm is null;

-- ---------------------------------------------------------------------------
-- Kategoriler, paket tanımları, ürünler
-- ---------------------------------------------------------------------------
insert into public.categories (id, name) values
  (pg_temp.sid('cat_pilates'), 'Pilates'),
  (pg_temp.sid('cat_fonk'),    'Fonksiyonel Antrenman')
on conflict do nothing;

insert into public.package_definitions (id, category_id, name, session_count, validity_days, price) values
  (pg_temp.sid('def_p8'),  pg_temp.sid('cat_pilates'), 'Pilates 8 Ders',      8, 30, 2400),
  (pg_temp.sid('def_p12'), pg_temp.sid('cat_pilates'), 'Pilates 12 Ders',    12, 30, 3300),
  (pg_temp.sid('def_f8'),  pg_temp.sid('cat_fonk'),    'Fonksiyonel 8 Ders',  8, 30, 2000),
  (pg_temp.sid('def_f16'), pg_temp.sid('cat_fonk'),    'Fonksiyonel 16 Ders',16, 40, 3600)
on conflict do nothing;

insert into public.products (id, name, price) values
  (pg_temp.sid('prd_su'),     'Su',          20),
  (pg_temp.sid('prd_bar'),    'Protein Bar', 60),
  (pg_temp.sid('prd_shake'),  'Protein Shake', 120)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Ders takvimi: bugünden itibaren 14 gün (İstanbul saatiyle), pazar hariç
--   10:00 Pilates grup (Ayşe)   12:00 Pilates bireysel (Selin)
--   18:00 Fonksiyonel grup (Mert)   19:30 Pilates grup (Ayşe)
-- ---------------------------------------------------------------------------
insert into public.classes
  (id, trainer_id, category_id, class_type, capacity, title, starts_at, ends_at, created_by)
select pg_temp.sid('class:' || d::date || ':' || s.slot),
       pg_temp.sid(s.trainer), pg_temp.sid(s.cat), s.ctype::public.class_type,
       case when s.ctype = 'individual' then 1 else 6 end, s.title,
       (d::date + s.at) at time zone 'Europe/Istanbul',
       (d::date + s.at + interval '50 minutes') at time zone 'Europe/Istanbul',
       pg_temp.sid('yonetici')
from generate_series((now() at time zone 'Europe/Istanbul')::date,
                     (now() at time zone 'Europe/Istanbul')::date + 13, interval '1 day') d
cross join (values
  ('p10', 'egitmen1', 'cat_pilates', 'group',      time '10:00', 'Sabah Pilates'),
  ('p12', 'egitmen3', 'cat_pilates', 'individual', time '12:00', 'Birebir Pilates'),
  ('f18', 'egitmen2', 'cat_fonk',    'group',      time '18:00', 'Akşam Fonksiyonel'),
  ('p19', 'egitmen1', 'cat_pilates', 'group',      time '19:30', 'Akşam Pilates')
) s(slot, trainer, cat, ctype, at, title)
where extract(isodow from d) <> 7
  and (d::date + s.at) at time zone 'Europe/Istanbul' > now()
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Paketler, cüzdan yüklemeleri (yönetici olarak) ve örnek rezervasyonlar (üye olarak)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims',
  json_build_object('sub', pg_temp.sid('yonetici'), 'role', 'authenticated')::text, false);

do $seed$
begin
  perform public.assign_package(pg_temp.sid('uye1'), pg_temp.sid('def_p8'),  pg_temp.sid('pkg:uye1'));
  perform public.assign_package(pg_temp.sid('uye2'), pg_temp.sid('def_p12'), pg_temp.sid('pkg:uye2'));
  perform public.assign_package(pg_temp.sid('uye3'), pg_temp.sid('def_f8'),  pg_temp.sid('pkg:uye3'));
  perform public.assign_package(pg_temp.sid('uye4'), pg_temp.sid('def_f16'), pg_temp.sid('pkg:uye4'));
  perform public.assign_package(pg_temp.sid('uye6'), pg_temp.sid('def_p8'),  pg_temp.sid('pkg:uye6'));
  perform public.admin_wallet_topup(pg_temp.sid('uye1'), 500, pg_temp.sid('topup:uye1'), 'Deneme yüklemesi');
  perform public.admin_wallet_topup(pg_temp.sid('uye2'), 200, pg_temp.sid('topup:uye2'), 'Deneme yüklemesi');
end
$seed$;

-- Yarınki derslere örnek rezervasyonlar (book_class üye kimliğiyle çağrılır)
do $seed$
declare
  v_day  date := (now() at time zone 'Europe/Istanbul')::date + 1;
  v_r    record;
begin
  -- Yarın pazarsa bir sonraki güne kaydır
  if extract(isodow from v_day) = 7 then v_day := v_day + 1; end if;
  for v_r in select * from (values
      ('uye1', 'p10'), ('uye2', 'p10'), ('uye4', 'f18')) x(handle, slot)
  loop
    if exists (select 1 from public.classes where id = pg_temp.sid('class:' || v_day || ':' || v_r.slot)) then
      perform set_config('request.jwt.claims',
        json_build_object('sub', pg_temp.sid(v_r.handle), 'role', 'authenticated')::text, true);
      perform public.book_class(pg_temp.sid('class:' || v_day || ':' || v_r.slot),
                                pg_temp.sid('res:' || v_r.handle || ':' || v_day || ':' || v_r.slot));
    end if;
  end loop;
end
$seed$;

select p.role, count(*) as hesap from public.profiles p
join auth.users u on u.id = p.id
where u.email like '%@casper.test'
group by p.role order by p.role;
