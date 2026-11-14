-- Ders türü kategoriye bağlı (14.11.2026, stüdyo kararı)
--
-- Sorun: kategori ve ders türü (bireysel/grup) bağımsız seçiliyordu. "Özel Ders"
-- kategorisinde grup dersi açılabiliyor, grup paketi olan üye "özel ders" gibi görünen
-- bir derse girebiliyordu. Artık her kategorinin tek bir ders türü var ve sınıf bu türle
-- açılmak zorunda. Kurallar: S-07, S-08 (docs/BUSINESS_RULES.md).

alter table public.categories
  add column if not exists class_type public.class_type not null default 'group';

comment on column public.categories.class_type is
  'Bu kategoride açılan derslerin türü: individual (1 kişi) veya group (6 kişi)';

-- Mevcut kategoriler: adında "Özel" geçenler bireysel, diğerleri grup
update public.categories set class_type = 'individual'
where name ilike '%özel%' and class_type <> 'individual';

-- Ders, kategorisinin türüyle açılmalı
create or replace function private.enforce_category_class_type()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type public.class_type;
begin
  select class_type into v_type from public.categories where id = new.category_id;
  if v_type is not null and new.class_type <> v_type then
    raise exception 'CLASS_TYPE_MISMATCH' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists classes_category_class_type on public.classes;
create trigger classes_category_class_type
  before insert or update of category_id, class_type on public.classes
  for each row execute function private.enforce_category_class_type();

-- Var olan uyumsuz dersleri düzelt (kontenjan izin veriyorsa); trigger'ı atlamak için
-- tür ve kapasite birlikte güncellenir.
update public.classes c
set class_type = cat.class_type,
    capacity = case when cat.class_type = 'individual' then 1 else 6 end
from public.categories cat
where cat.id = c.category_id
  and c.class_type <> cat.class_type
  and c.booked_count <= case when cat.class_type = 'individual' then 1 else 6 end;

revoke all on function private.enforce_category_class_type() from public, anon, authenticated;
