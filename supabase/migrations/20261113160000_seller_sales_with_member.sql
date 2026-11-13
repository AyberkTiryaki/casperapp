-- Eğitmenin "Satışlarım" listesinde satışın kime yapıldığı görünür (13.11.2026, stüdyo isteği).
--
-- Eğitmen profiles tablosunu doğrudan okuyamaz (Y-05); bu RPC yalnızca alıcının ADINI
-- döndürür (search_members ile aynı düzey). Eğitmen yalnızca kendi satışlarını,
-- yönetici herhangi bir satıcının satışlarını görür.

create or replace function public.seller_sales(p_seller_id uuid default null)
returns table (
  id uuid, member_id uuid, member_name text, product_name text, quantity integer,
  unit_price numeric, total numeric, created_at timestamptz, reversed_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_seller uuid := coalesce(p_seller_id, v_uid);
begin
  if v_uid is null or not private.is_staff() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if v_seller <> v_uid and not private.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return query
  select s.id, s.member_id, p.full_name, pr.name, s.quantity,
         s.unit_price::numeric, s.total::numeric, s.created_at, s.reversed_at
  from public.sales s
  join public.profiles p on p.id = s.member_id
  join public.products pr on pr.id = s.product_id
  where s.seller_id = v_seller
  order by s.created_at desc
  limit 200;
end;
$$;
revoke all on function public.seller_sales(uuid) from public, anon;
grant execute on function public.seller_sales(uuid) to authenticated;
