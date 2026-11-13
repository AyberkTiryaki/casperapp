-- Yönetici kişi listelerinde güncel cüzdan bakiyesi (13.11.2026, stüdyo isteği).
-- Dönüş tipleri değiştiği için fonksiyonlar yeniden oluşturulur. Bakiye yalnızca
-- yöneticiye döner; eğitmen üye aramasında null görür (Y-05).

drop function if exists public.admin_list_users(text);
create function public.admin_list_users(p_query text default '')
returns table (id uuid, full_name text, role public.user_role, is_active boolean, email text,
               birth_date date, height_cm integer, weight_kg numeric, wallet_balance numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := lower(btrim(coalesce(p_query, '')));
begin
  perform private.require_admin();
  return query
  select p.id, p.full_name, p.role, p.is_active, u.email::text,
         p.birth_date, p.height_cm::integer, p.weight_kg::numeric,
         coalesce(w.balance, 0)::numeric
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.wallets w on w.member_id = p.id
  where v_q = ''
     or lower(p.full_name) like '%' || v_q || '%'
     or lower(u.email) like '%' || v_q || '%'
  order by p.full_name
  limit 50;
end;
$$;
revoke all on function public.admin_list_users(text) from public, anon;
grant execute on function public.admin_list_users(text) to authenticated;

drop function if exists public.search_members(text);
create function public.search_members(p_query text default '')
returns table (id uuid, full_name text, email text, wallet_balance numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name,
         case when private.is_admin() then u.email::text end,
         case when private.is_admin() then coalesce(w.balance, 0)::numeric end
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.wallets w on w.member_id = p.id
  where private.is_staff()
    and p.role = 'member'::public.user_role and p.is_active
    and (coalesce(btrim(p_query), '') = ''
         or lower(p.full_name) like '%' || lower(btrim(p_query)) || '%'
         or (private.is_admin() and lower(u.email) like '%' || lower(btrim(p_query)) || '%'))
  order by p.full_name
  limit 50
$$;
revoke all on function public.search_members(text) from public, anon;
grant execute on function public.search_members(text) to authenticated;
