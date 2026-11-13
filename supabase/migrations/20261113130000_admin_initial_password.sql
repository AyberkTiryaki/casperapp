-- Yöneticinin açtığı hesaba kısa geçici şifre (ör. 1234) verebilmek için.
--
-- Supabase Auth proje genelinde en az 8 karakter ister; bu kural üyenin kendi kaydı için
-- korunur. admin-create-user Edge Function'ı hesabı rastgele uzun bir şifreyle açar,
-- ardından yöneticinin girdiği şifreyi bu fonksiyonla yazar.
-- Yalnızca service_role çağırabilir (uygulama kullanıcıları çağıramaz).

create or replace function public.admin_set_initial_password(p_user_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_password is null or char_length(p_password) < 4 or char_length(p_password) > 72 then
    raise exception 'WEAK_PASSWORD' using errcode = 'P0001';
  end if;
  update auth.users
  set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = p_user_id;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.admin_set_initial_password(uuid, text) from public, anon, authenticated;
grant execute on function public.admin_set_initial_password(uuid, text) to service_role;
