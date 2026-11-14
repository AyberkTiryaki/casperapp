-- Yönetici, üye veya eğitmenin şifresini geçici bir şifreyle sıfırlar (14.11.2026)
--
-- E-postasına ulaşamayan ya da telefonunu değiştiren üye için. Kurallar (Y-11):
--  * Yalnızca yönetici çağırır.
--  * Hedef kendisi veya başka bir yönetici olamaz (yöneticiler e-postayla sıfırlar).
--  * Şifre 4–72 karakter (yöneticinin açtığı hesaplardaki kuralla aynı).
--  * Hedefin açık oturumları kapatılır; yeni şifreyle yeniden giriş yapar.
--  * İşlem denetim kaydına yazılır (şifre yazılmaz).

create or replace function public.admin_reset_password(p_user_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_role public.user_role;
begin
  if v_uid is null or not private.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = v_uid then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  select role into v_role from public.profiles where id = p_user_id;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_role = 'admin'::public.user_role then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

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

  -- Açık oturumları kapat (yenileme anahtarları oturumla birlikte silinir)
  delete from auth.sessions where user_id = p_user_id;

  perform private.audit('admin_reset_password', 'profiles', p_user_id::text,
    jsonb_build_object('target_role', v_role));
end;
$$;

revoke all on function public.admin_reset_password(uuid, text) from public, anon;
grant execute on function public.admin_reset_password(uuid, text) to authenticated;
