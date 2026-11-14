-- Casper Training Studio — güncel paket listesi (14.11.2026, stüdyo sahibinden).
-- Tekrar çalıştırılabilir. Eski kategori ve paket tanımları SİLİNMEZ, pasife alınır
-- (iş kuralı: geçmiş atamalar tanıma bağlı kalır); yeni atamada seçilemezler.
--   supabase db query --remote --yes -f supabase/seed/packages_2026_11.sql
--
-- Geçerlilik (P kuralı, veritabanı kısıtı): 8 ve 12 ders 30 gün, 16 ve 20 ders 40 gün.

create temp table new_packages (category text, sessions int, price numeric) on commit drop;
insert into new_packages values
  ('Atletik Özel Ders',        8, 15000),
  ('Atletik Özel Ders',       12, 18000),
  ('Atletik Özel Ders',       16, 22000),
  ('Atletik Performans Grup',  8,  5000),
  ('Atletik Performans Grup', 12,  8000),
  ('Özel Ders',                8, 12000),
  ('Özel Ders',               12, 15000),
  ('Özel Ders',               16, 18000),
  ('Özel Ders',               20, 20000);

-- 1) Eski kategoriler ve tanımlar pasife
update public.categories set is_active = false
where name not in (select distinct category from new_packages) and is_active;

update public.package_definitions d set is_active = false, updated_at = now()
from public.categories c
where c.id = d.category_id and c.name not in (select distinct category from new_packages)
  and d.is_active;

-- 2) Yeni kategoriler (varsa yeniden aktif)
insert into public.categories (name)
select distinct category from new_packages
on conflict (name) do update set is_active = true;

-- 3) Yeni tanımlar: aynı kategoride aynı ders sayısı varsa fiyatı güncellenir, yoksa eklenir
update public.package_definitions d
set price = n.price, is_active = true, updated_at = now(),
    name = n.category || ' · ' || n.sessions || ' Ders'
from new_packages n
join public.categories c on c.name = n.category
where d.category_id = c.id and d.session_count = n.sessions;

insert into public.package_definitions (category_id, name, session_count, validity_days, price)
select c.id, n.category || ' · ' || n.sessions || ' Ders', n.sessions,
       case when n.sessions in (8, 12) then 30 else 40 end, n.price
from new_packages n
join public.categories c on c.name = n.category
where not exists (
  select 1 from public.package_definitions d
  where d.category_id = c.id and d.session_count = n.sessions);

select c.name as kategori, d.session_count as ders, d.validity_days as gun, d.price as fiyat
from public.package_definitions d join public.categories c on c.id = d.category_id
where d.is_active and c.is_active
order by c.name, d.session_count;
