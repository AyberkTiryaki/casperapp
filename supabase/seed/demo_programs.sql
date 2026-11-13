-- Casper Training Studio — deneme verisi: antrenman programları ve vücut ölçümleri.
-- demo.sql ve demo_extra.sql'den SONRA, 20261113150000 migration'ı yüklendikten sonra çalıştırılır.
--   supabase db query --remote --yes -f supabase/seed/demo_programs.sql
-- Tekrar çalıştırılabilir: sabit kimlikli kayıtlar varsa atlanır.
-- Silmek için: supabase/seed/demo_cleanup.sql
--
-- Eklenenler
--   uye1  eski (pasif) "Başlangıç Programı" + aktif "Pilates + Kuvvet" (Ayşe Eğitmen);
--         5 hafta boyunca 6 ölçüm (son ölçümü üye kendisi girdi)
--   uye2  4 ölçüm (yönetici ve üye girdi); programı yok (boş durum ekranı için)
--   uye4  aktif "Fonksiyonel Güç" programı (Mert Eğitmen)
-- Kayıtlar doğrudan eklenir (RPC "eğitmenin üyesi" kuralını arar; deneme verisinde
-- rezervasyonlar güne göre değiştiği için buna bağlanmaz). Denetim kaydı yazılmaz.

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-seed:' || p)::uuid $$;

-- ---------------------------------------------------------------------------
-- Programlar (önce pasif olan; üyenin başka aktif programı varsa aktif kayıt atlanır)
-- ---------------------------------------------------------------------------
insert into public.workout_programs
  (id, member_id, title, goal, notes, is_active, created_by, updated_by, created_at, updated_at)
select pg_temp.sid(v.pid), pg_temp.sid(v.member), v.title, v.goal, v.notes, v.is_active,
       pg_temp.sid(v.trainer), pg_temp.sid(v.trainer),
       now() - make_interval(days => v.days_ago), now() - make_interval(days => v.days_ago)
from (values
  ('prog:uye1:eski', 'uye1', 'egitmen1', 'Başlangıç Programı', 'Temel dayanıklılık',
   'Haftada 2 gün. Hareketleri yavaş ve kontrollü yapın.', false, 42),
  ('prog:uye1:aktif', 'uye1', 'egitmen1', 'Pilates + Kuvvet (4 hafta)', 'Merkez bölge ve duruş',
   'Haftada 3 gün. Her antrenmandan önce 5 dk ısınma, sonrasında esneme.', true, 7),
  ('prog:uye4:aktif', 'uye4', 'egitmen2', 'Fonksiyonel Güç', 'Genel kuvvet',
   'Ağırlıkları formu bozmadan artırın.', true, 5)
) v(pid, member, trainer, title, goal, notes, is_active, days_ago)
where exists (select 1 from public.profiles p where p.id = pg_temp.sid(v.member))
order by v.is_active
on conflict do nothing;

insert into public.workout_program_items
  (id, program_id, day_label, exercise, sets, reps, rest_seconds, note, sort_order)
select pg_temp.sid(v.pid || ':item:' || v.ord), pg_temp.sid(v.pid), v.day_label, v.exercise,
       v.sets, v.reps, v.rest, v.note, v.ord
from (values
  ('prog:uye1:eski', 1, 'Gün 1', 'Yürüyüş (koşu bandı)', null::int, '15 dk', null::int, 'Orta tempo'),
  ('prog:uye1:eski', 2, 'Gün 1', 'Squat (vücut ağırlığı)', 2, '12', 60, null),
  ('prog:uye1:eski', 3, 'Gün 1', 'Plank', 2, '20 sn', 45, null),
  ('prog:uye1:eski', 4, 'Gün 2', 'Köprü (glute bridge)', 2, '15', 60, null),
  ('prog:uye1:eski', 5, 'Gün 2', 'Bird dog', 2, '10', 45, 'Her iki taraf'),

  ('prog:uye1:aktif', 1, 'Pazartesi', 'Hundred', 1, '100 nefes', 30, 'Bel yere yakın'),
  ('prog:uye1:aktif', 2, 'Pazartesi', 'Roll up', 3, '8', 45, null),
  ('prog:uye1:aktif', 3, 'Pazartesi', 'Goblet squat', 3, '12', 60, '8 kg'),
  ('prog:uye1:aktif', 4, 'Pazartesi', 'Plank', 3, '40 sn', 45, null),
  ('prog:uye1:aktif', 5, 'Çarşamba', 'Side kick serisi', 2, '10', 30, 'Her iki taraf'),
  ('prog:uye1:aktif', 6, 'Çarşamba', 'Romanian deadlift', 3, '10', 75, '12 kg dambıl'),
  ('prog:uye1:aktif', 7, 'Çarşamba', 'Swimming', 3, '30 sn', 30, null),
  ('prog:uye1:aktif', 8, 'Cuma', 'Teaser', 3, '6', 45, null),
  ('prog:uye1:aktif', 9, 'Cuma', 'Lunge', 3, '10', 60, 'Her bacak'),
  ('prog:uye1:aktif', 10, 'Cuma', 'Esneme', null, '10 dk', null, null),

  ('prog:uye4:aktif', 1, 'Gün 1', 'Kettlebell swing', 4, '15', 60, '12 kg'),
  ('prog:uye4:aktif', 2, 'Gün 1', 'Şınav', 3, '10', 60, null),
  ('prog:uye4:aktif', 3, 'Gün 1', 'TRX row', 3, '12', 60, null),
  ('prog:uye4:aktif', 4, 'Gün 2', 'Box jump', 4, '8', 90, null),
  ('prog:uye4:aktif', 5, 'Gün 2', 'Farmer walk', 3, '30 m', 60, '2 x 16 kg'),
  ('prog:uye4:aktif', 6, 'Gün 2', 'Mountain climber', 3, '30 sn', 30, null)
) v(pid, ord, day_label, exercise, sets, reps, rest, note)
where exists (select 1 from public.workout_programs wp where wp.id = pg_temp.sid(v.pid))
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Ölçümler (tarihler İstanbul gününe göre bugünden geriye)
-- ---------------------------------------------------------------------------
insert into public.body_measurements
  (id, member_id, measured_on, weight_kg, body_fat_pct, muscle_kg, waist_cm, hip_cm,
   chest_cm, arm_cm, thigh_cm, note, created_by, created_at)
select pg_temp.sid('olcum:' || v.member || ':' || v.days_ago), pg_temp.sid(v.member),
       (now() at time zone 'Europe/Istanbul')::date - v.days_ago,
       v.weight, v.fat, v.muscle, v.waist, v.hip, v.chest, v.arm, v.thigh, v.note,
       pg_temp.sid(v.by), now() - make_interval(days => v.days_ago)
from (values
  ('uye1', 35, 70.2, 24.5, 29.8, 82.0, 98.0, 92.0, 29.0, 56.0, 'İlk ölçüm', 'egitmen1'),
  ('uye1', 28, 69.8, 24.1, 29.9, 81.5, 97.5, null, null, null, null, 'egitmen1'),
  ('uye1', 21, 69.9, 23.8, 30.1, 81.0, 97.0, null, null, null, 'Tatil dönüşü', 'egitmen1'),
  ('uye1', 14, 69.1, 23.4, 30.2, 80.5, 96.5, 91.5, 29.5, 55.5, null, 'egitmen1'),
  ('uye1', 7,  68.8, 23.0, 30.4, 79.5, 96.0, null, null, null, null, 'egitmen1'),
  ('uye1', 0,  68.5, null, null, null, null, null, null, null, 'Sabah, aç karnına', 'uye1'),
  ('uye2', 21, 59.4, 27.0, null, 71.0, 95.0, null, null, null, 'İlk ölçüm', 'yonetici'),
  ('uye2', 14, 58.9, 26.6, null, 70.5, 94.5, null, null, null, null, 'yonetici'),
  ('uye2', 7,  58.6, null, null, 70.0, null, null, null, null, null, 'uye2'),
  ('uye2', 1,  58.0, 26.1, null, 69.5, 94.0, null, null, null, null, 'uye2')
) v(member, days_ago, weight, fat, muscle, waist, hip, chest, arm, thigh, note, by)
where exists (select 1 from public.profiles p where p.id = pg_temp.sid(v.member))
on conflict do nothing;

select
  (select count(*) from public.workout_programs wp
     join auth.users u on u.id = wp.member_id where u.email like '%@casper.test') as program,
  (select count(*) from public.workout_program_items i
     join public.workout_programs wp on wp.id = i.program_id
     join auth.users u on u.id = wp.member_id where u.email like '%@casper.test') as hareket,
  (select count(*) from public.body_measurements bm
     join auth.users u on u.id = bm.member_id where u.email like '%@casper.test') as olcum;
