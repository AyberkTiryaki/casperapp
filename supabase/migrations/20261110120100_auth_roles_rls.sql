-- Casper Training Studio — kayıt tetikleyicisi, rol yardımcıları, RLS ve yetkiler
-- Kural: rol yalnızca sunucuda tutulur; istemci profiles.role sütununu yazamaz.

-- ---------------------------------------------------------------------------
-- private şema: API'ye açık değildir (PostgREST yalnızca public şemayı sunar)
-- ---------------------------------------------------------------------------
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

-- Oturumdaki kullanıcının rolü (pasif hesap = rol yok)
create or replace function private.user_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = (select auth.uid()) and p.is_active
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.user_role() = 'admin'::public.user_role, false)
$$;

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    private.user_role() in ('admin'::public.user_role, 'trainer'::public.user_role),
    false)
$$;

create or replace function private.require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not private.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501',
      hint = 'Bu işlem için yönetici yetkisi gerekir.';
  end if;
  return v_uid;
end;
$$;

create or replace function private.audit(
  p_action text, p_entity text, p_entity_id text, p_details jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (actor_id, action, entity, entity_id, details)
  values (auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_details, '{}'::jsonb))
$$;

-- Kullanıcıdan gelen metadata güvenilmezdir: hatalı değer kaydı düşürmez, null olur
create or replace function private.safe_date(p text)
returns date
language plpgsql
stable
set search_path = ''
as $$
begin
  return p::date;
exception when others then
  return null;
end;
$$;

create or replace function private.safe_numeric(p text)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
begin
  return p::numeric;
exception when others then
  return null;
end;
$$;

revoke all on all functions in schema private from public, anon;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Kayıt olunca profil + cüzdan + KVKK onayı
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta    jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_birth   date := private.safe_date(v_meta ->> 'birth_date');
  v_height  numeric := private.safe_numeric(v_meta ->> 'height_cm');
  v_weight  numeric := private.safe_numeric(v_meta ->> 'weight_kg');
  v_version text := nullif(btrim(coalesce(v_meta ->> 'kvkk_version', '')), '');
begin
  -- Rol HER ZAMAN 'member' başlar; metadata içindeki rol benzeri alanlar yok sayılır.
  insert into public.profiles (id, full_name, birth_date, height_cm, weight_kg, role)
  values (
    new.id,
    left(btrim(coalesce(v_meta ->> 'full_name', '')), 120),
    case when v_birth > date '1900-01-01' and v_birth < current_date then v_birth end,
    case when v_height between 50 and 260 then round(v_height)::integer end,
    case when v_weight between 20 and 400 then round(v_weight, 1) end,
    'member'::public.user_role
  )
  on conflict (id) do nothing;

  insert into public.wallets (member_id) values (new.id)
  on conflict (member_id) do nothing;

  if coalesce(v_meta ->> 'kvkk_accepted', '') = 'true' and v_version is not null then
    insert into public.consents (user_id, consent_type, text_version)
    values (new.id, 'kvkk', left(v_version, 40))
    on conflict do nothing;
  end if;

  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- updated_at
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.touch_updated_at() from public, anon, authenticated;

create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger package_definitions_touch before update on public.package_definitions
  for each row execute function private.touch_updated_at();
create trigger products_touch before update on public.products
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Rol ve hesap yönetimi (yalnızca yönetici)
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_role(p_user_id uuid, p_role public.user_role)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_old   public.profiles;
  v_new   public.profiles;
begin
  select * into v_old from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  -- Yönetici kendi rolünü düşüremez (sistemin yöneticisiz kalmasını önler)
  if p_user_id = v_admin and p_role <> 'admin'::public.user_role then
    raise exception 'CANNOT_DEMOTE_SELF' using errcode = 'P0001';
  end if;

  update public.profiles set role = p_role where id = p_user_id returning * into v_new;
  perform private.audit('set_role', 'profiles', p_user_id::text,
    jsonb_build_object('from', v_old.role, 'to', p_role));
  return v_new;
end;
$$;

create or replace function public.admin_set_active(p_user_id uuid, p_is_active boolean)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_new   public.profiles;
begin
  if p_user_id = v_admin and not p_is_active then
    raise exception 'CANNOT_DEACTIVATE_SELF' using errcode = 'P0001';
  end if;
  update public.profiles set is_active = p_is_active where id = p_user_id
  returning * into v_new;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform private.audit('set_active', 'profiles', p_user_id::text,
    jsonb_build_object('is_active', p_is_active));
  return v_new;
end;
$$;

-- KVKK metni güncellenince kullanıcının yeni sürümü onaylaması için
create or replace function public.accept_kvkk(p_text_version text)
returns public.consents
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.consents;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if p_text_version is null or char_length(btrim(p_text_version)) not between 1 and 40 then
    raise exception 'INVALID_VERSION' using errcode = 'P0001';
  end if;
  insert into public.consents (user_id, consent_type, text_version)
  values (v_uid, 'kvkk', btrim(p_text_version))
  on conflict (user_id, consent_type, text_version) do nothing;
  select * into v_row from public.consents
  where user_id = v_uid and consent_type = 'kvkk' and text_version = btrim(p_text_version);
  return v_row;
end;
$$;

-- Üyelerin eğitmen adını görebilmesi için (profil tablosu başkalarına kapalıdır)
create or replace function public.list_trainers()
returns table (id uuid, full_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name
  from public.profiles p
  where p.role = 'trainer'::public.user_role and p.is_active
    and (select auth.uid()) is not null
  order by p.full_name
$$;

-- Eğitmen/yönetici: üye arama (yalnızca ad; boy/kilo/doğum tarihi dönmez)
create or replace function public.search_members(p_query text default '')
returns table (id uuid, full_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name
  from public.profiles p
  where private.is_staff()
    and p.role = 'member'::public.user_role and p.is_active
    and (coalesce(btrim(p_query), '') = ''
         or lower(p.full_name) like '%' || lower(btrim(p_query)) || '%')
  order by p.full_name
  limit 50
$$;

-- Dersin eğitmeni veya yönetici: katılımcı listesi
create or replace function public.class_participants(p_class_id uuid)
returns table (reservation_id uuid, member_id uuid, full_name text,
               status public.reservation_status, booked_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.member_id, p.full_name, r.status, r.booked_at
  from public.reservations r
  join public.classes c on c.id = r.class_id
  join public.profiles p on p.id = r.member_id
  where r.class_id = p_class_id
    and r.status <> 'cancelled'::public.reservation_status
    and (private.is_admin()
         or (private.is_staff() and c.trainer_id = (select auth.uid())))
  order by r.booked_at
$$;

-- ---------------------------------------------------------------------------
-- Tablo yetkileri: varsayılanları kaldır, yalnızca gerekeni ver.
-- Yazma işlemlerinin çoğu SECURITY DEFINER RPC'ler üzerinden yapılır.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from anon;
-- Not: PUBLIC'in varsayılan EXECUTE yetkisi şema bazında kaldırılamaz; bu yüzden her
-- fonksiyon için ayrıca "revoke ... from public, anon" yazılır.

grant select on all tables in schema public to authenticated;
grant update (full_name, birth_date, height_cm, weight_kg) on public.profiles to authenticated;
grant insert, update, delete on public.categories, public.package_definitions, public.products
  to authenticated; -- RLS: yalnızca yönetici
grant insert, update, delete on public.device_tokens to authenticated;
grant insert on public.account_deletion_requests to authenticated;
grant update (status, note, processed_at, processed_by)
  on public.account_deletion_requests to authenticated; -- RLS: yalnızca yönetici

-- ---------------------------------------------------------------------------
-- RLS — her tabloda açık
-- ---------------------------------------------------------------------------
alter table public.profiles                  enable row level security;
alter table public.consents                  enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.categories                enable row level security;
alter table public.package_definitions       enable row level security;
alter table public.member_packages           enable row level security;
alter table public.package_freezes           enable row level security;
alter table public.classes                   enable row level security;
alter table public.reservations              enable row level security;
alter table public.credit_ledger             enable row level security;
alter table public.products                  enable row level security;
alter table public.wallets                   enable row level security;
alter table public.sales                     enable row level security;
alter table public.wallet_ledger             enable row level security;
alter table public.audit_log                 enable row level security;
alter table public.device_tokens             enable row level security;
alter table public.notifications             enable row level security;

-- profiles: kendi satırı veya yönetici. Eğitmen başka profilleri doğrudan göremez
-- (search_members / class_participants RPC'leri yalnızca adı döndürür).
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_admin());
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy profiles_update_admin on public.profiles for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
-- insert/delete politikası yok: profil yalnızca tetikleyiciyle oluşur.

create policy consents_select on public.consents for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());

create policy deletion_select on public.account_deletion_requests for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());
create policy deletion_insert_own on public.account_deletion_requests for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'pending'
              and processed_at is null and processed_by is null);
create policy deletion_update_admin on public.account_deletion_requests for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- Tanım tabloları: herkes (giriş yapmış) aktifleri okur; yönetici hepsini okur ve yazar
create policy categories_select on public.categories for select to authenticated
  using (is_active or private.is_admin());
create policy categories_admin_insert on public.categories for insert to authenticated
  with check (private.is_admin());
create policy categories_admin_update on public.categories for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy categories_admin_delete on public.categories for delete to authenticated
  using (private.is_admin());

create policy package_definitions_select on public.package_definitions for select to authenticated
  using (is_active or private.is_admin());
create policy package_definitions_admin_insert on public.package_definitions for insert to authenticated
  with check (private.is_admin());
create policy package_definitions_admin_update on public.package_definitions for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy package_definitions_admin_delete on public.package_definitions for delete to authenticated
  using (private.is_admin());

create policy products_select on public.products for select to authenticated
  using (is_active or private.is_admin());
create policy products_admin_insert on public.products for insert to authenticated
  with check (private.is_admin());
create policy products_admin_update on public.products for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy products_admin_delete on public.products for delete to authenticated
  using (private.is_admin());

-- Üye paketleri, dondurma, hak hareketleri: sahibi veya yönetici (yazma yalnızca RPC)
create policy member_packages_select on public.member_packages for select to authenticated
  using (member_id = (select auth.uid()) or private.is_admin());

create policy package_freezes_select on public.package_freezes for select to authenticated
  using (private.is_admin() or exists (
    select 1 from public.member_packages mp
    where mp.id = member_package_id and mp.member_id = (select auth.uid())));

create policy credit_ledger_select on public.credit_ledger for select to authenticated
  using (member_id = (select auth.uid()) or private.is_admin());

-- Dersler: giriş yapmış herkes takvimi ve kalan kontenjanı görür (yazma yalnızca RPC)
create policy classes_select on public.classes for select to authenticated
  using (true);

-- Rezervasyonlar: sahibi, dersin eğitmeni veya yönetici
create policy reservations_select on public.reservations for select to authenticated
  using (
    member_id = (select auth.uid())
    or private.is_admin()
    or (private.is_staff() and exists (
      select 1 from public.classes c
      where c.id = class_id and c.trainer_id = (select auth.uid())))
  );

-- Cüzdan ve satışlar
create policy wallets_select on public.wallets for select to authenticated
  using (member_id = (select auth.uid()) or private.is_admin());
create policy wallet_ledger_select on public.wallet_ledger for select to authenticated
  using (member_id = (select auth.uid()) or private.is_admin());
create policy sales_select on public.sales for select to authenticated
  using (
    member_id = (select auth.uid())
    or private.is_admin()
    or (private.is_staff() and seller_id = (select auth.uid()))
  );

create policy audit_log_select on public.audit_log for select to authenticated
  using (private.is_admin());

-- Cihaz bağlantıları: yalnızca sahibi
create policy device_tokens_select on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));
create policy device_tokens_insert on public.device_tokens for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy device_tokens_update on public.device_tokens for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy device_tokens_delete on public.device_tokens for delete to authenticated
  using (user_id = (select auth.uid()));

create policy notifications_select on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());

-- ---------------------------------------------------------------------------
-- Fonksiyon yetkileri
-- ---------------------------------------------------------------------------
revoke all on function
  public.admin_set_role(uuid, public.user_role),
  public.admin_set_active(uuid, boolean),
  public.accept_kvkk(text),
  public.list_trainers(),
  public.search_members(text),
  public.class_participants(uuid)
from public, anon;
grant execute on function
  public.admin_set_role(uuid, public.user_role),
  public.admin_set_active(uuid, boolean),
  public.accept_kvkk(text),
  public.list_trainers(),
  public.search_members(text),
  public.class_participants(uuid)
to authenticated;
