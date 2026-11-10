-- Adım 3 (paket yönetimi): üye, pasife alınmış olsa bile KENDİ paketinin bağlı olduğu
-- paket tanımını ve kategoriyi okuyabilmelidir (paket adı / kategori adı gösterimi).
-- Mevcut "aktif olanlar herkese" politikalarına ek (permissive politikalar OR'lanır).

create policy package_definitions_select_own_used on public.package_definitions
  for select to authenticated
  using (exists (
    select 1 from public.member_packages mp
    where mp.definition_id = package_definitions.id
      and mp.member_id = (select auth.uid())));

create policy categories_select_own_used on public.categories
  for select to authenticated
  using (exists (
    select 1 from public.member_packages mp
    where mp.category_id = categories.id
      and mp.member_id = (select auth.uid())));

-- Yönetim ekranındaki listeler için
create index if not exists member_packages_member_status_idx
  on public.member_packages (member_id, status, activated_at desc);
