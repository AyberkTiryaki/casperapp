-- Casper Training Studio: pasif (eski) kategorileri ve onlara bağlı DENEME verisini kalıcı siler.
-- 14.11.2026: Pilates / Fonksiyonel / Yoga / test kaldırıldı, temiz sayfa.
-- Güvenlik: etkilenen kayıtlardan biri @casper.test dışı bir kullanıcıya aitse hiçbir şey silinmez.
--   supabase db query --remote --yes -f supabase/seed/remove_old_categories.sql
do $$
declare
  cats uuid[] := array(select id from public.categories where not is_active);
  defs uuid[];
  mps  uuid[];
  cls  uuid[];
  res  uuid[];
  n    int;
begin
  if cardinality(cats) = 0 then
    raise notice 'Silinecek pasif kategori yok';
    return;
  end if;
  defs := array(select id from public.package_definitions where category_id = any(cats));
  mps  := array(select id from public.member_packages
                where definition_id = any(defs) or category_id = any(cats));
  cls  := array(select id from public.classes where category_id = any(cats));
  res  := array(select id from public.reservations
                where class_id = any(cls) or member_package_id = any(mps));

  select count(*) into n from (
    select member_id as uid from public.member_packages where id = any(mps)
    union select trainer_id from public.classes where id = any(cls)
    union select member_id from public.reservations where id = any(res)
  ) x join auth.users u on u.id = x.uid
  where u.email not like '%@casper.test';
  if n > 0 then
    raise exception 'DURDURULDU: % gerçek kullanıcı etkileniyor, hiçbir şey silinmedi', n;
  end if;

  delete from public.notifications
  where payload ->> 'reservation_id' = any(res::text[])
     or payload ->> 'class_id' = any(cls::text[])
     or payload ->> 'package_id' = any(mps::text[]);
  delete from public.credit_ledger
  where reservation_id = any(res) or member_package_id = any(mps);
  delete from public.package_freezes where member_package_id = any(mps);
  delete from public.reservations where id = any(res);
  update public.member_packages set replaced_by = null where replaced_by = any(mps);
  delete from public.member_packages where id = any(mps);
  delete from public.classes where id = any(cls);
  delete from public.package_definitions where id = any(defs);
  delete from public.categories where id = any(cats);

  raise notice 'Silindi: % kategori, % tanım, % üye paketi, % ders, % rezervasyon',
    cardinality(cats), cardinality(defs), cardinality(mps), cardinality(cls), cardinality(res);
end
$$;

select c.name as kategori, c.is_active as aktif,
       (select count(*) from public.package_definitions d where d.category_id = c.id) as paket
from public.categories c order by c.name;
