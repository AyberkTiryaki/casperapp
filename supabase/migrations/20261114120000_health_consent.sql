-- Sağlık verisi açık rızası (KVKK md. 6, özel nitelikli veri)
--
-- Vücut ölçümleri yalnızca üyenin geçerli (geri alınmamış) 'health' rızası varken
-- kaydedilebilir. Rıza kayıtta isteğe bağlı verilir; sonradan profilden verilip geri
-- alınabilir. Geri alınınca üyenin tüm ölçümleri silinir. Rıza üyeliği ve rezervasyonu
-- etkilemez. Kurallar: K-09..K-12 (docs/BUSINESS_RULES.md).

alter table public.consents add column if not exists revoked_at timestamptz;

create or replace function private.has_health_consent(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.consents c
    where c.user_id = p_member_id
      and c.consent_type = 'health'
      and c.revoked_at is null)
$$;

-- Ölçüm tablosuna her yazım (RPC dahil) rızayı denetler
create or replace function private.require_health_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_health_consent(new.member_id) then
    raise exception 'HEALTH_CONSENT_REQUIRED' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists body_measurements_require_consent on public.body_measurements;
create trigger body_measurements_require_consent
  before insert or update of member_id on public.body_measurements
  for each row execute function private.require_health_consent();

-- ---------------------------------------------------------------------------
-- Kayıt tetikleyicisi: 'health_consent' + 'health_version' metadata alanları eklendi
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_birth    date := private.safe_date(v_meta ->> 'birth_date');
  v_height   numeric := private.safe_numeric(v_meta ->> 'height_cm');
  v_weight   numeric := private.safe_numeric(v_meta ->> 'weight_kg');
  v_version  text := nullif(btrim(coalesce(v_meta ->> 'kvkk_version', '')), '');
  v_health   text := nullif(btrim(coalesce(v_meta ->> 'health_version', '')), '');
  v_ref_code text := upper(regexp_replace(coalesce(v_meta ->> 'referral_code', ''), '\s', '', 'g'));
  v_referrer uuid;
  v_try      integer := 0;
begin
  -- Rol HER ZAMAN 'member' başlar; metadata içindeki rol benzeri alanlar yok sayılır.
  -- Referans kodu çakışırsa (unique) yeni kodla yeniden denenir.
  loop
    v_try := v_try + 1;
    begin
      insert into public.profiles
        (id, full_name, birth_date, height_cm, weight_kg, role, referral_code)
      values (
        new.id,
        left(btrim(coalesce(v_meta ->> 'full_name', '')), 120),
        case when v_birth > date '1900-01-01' and v_birth < current_date then v_birth end,
        case when v_height between 50 and 260 then round(v_height)::integer end,
        case when v_weight between 20 and 400 then round(v_weight, 1) end,
        'member'::public.user_role,
        private.generate_referral_code()
      )
      on conflict (id) do nothing;
      exit;
    exception when unique_violation then
      if v_try >= 10 then raise; end if;
    end;
  end loop;

  insert into public.wallets (member_id) values (new.id)
  on conflict (member_id) do nothing;

  if coalesce(v_meta ->> 'kvkk_accepted', '') = 'true' and v_version is not null then
    insert into public.consents (user_id, consent_type, text_version)
    values (new.id, 'kvkk', left(v_version, 40))
    on conflict do nothing;
  end if;

  -- Sağlık verisi açık rızası: isteğe bağlı, aydınlatma onayından ayrı (KVKK md. 6)
  if coalesce(v_meta ->> 'health_consent', '') = 'true' and v_health is not null then
    insert into public.consents (user_id, consent_type, text_version)
    values (new.id, 'health', left(v_health, 40))
    on conflict do nothing;
  end if;

  -- Referans: kod geçerliyse 'pending' kayıt. Geçersiz kod kaydı engellemez.
  if v_ref_code <> '' then
    select p.id into v_referrer
    from public.profiles p
    where p.referral_code = v_ref_code and p.id <> new.id and p.is_active;
    if v_referrer is not null then
      insert into public.referrals (referrer_id, referred_id, code_used)
      values (v_referrer, new.id, v_ref_code)
      on conflict (referred_id) do nothing;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: üye kendi sağlık verisi rızasını verir veya geri alır.
-- Geri alma: rıza kapanır ve üyenin TÜM ölçümleri silinir. Dönen değer: güncel durum.
-- ---------------------------------------------------------------------------
create or replace function public.set_health_consent(
  p_accept boolean, p_text_version text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_ver  text := btrim(coalesce(p_text_version, ''));
  v_n    integer;
begin
  if v_uid is null or private.user_role() is null then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_accept is null then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end if;

  if p_accept then
    if char_length(v_ver) not between 1 and 40 then
      raise exception 'INVALID_VERSION' using errcode = 'P0001';
    end if;
    insert into public.consents (user_id, consent_type, text_version)
    values (v_uid, 'health', v_ver)
    on conflict (user_id, consent_type, text_version)
      do update set revoked_at = null, accepted_at = now();
    perform private.audit('health_consent_give', 'consents', v_uid::text,
      jsonb_build_object('text_version', v_ver));
  else
    update public.consents set revoked_at = now()
    where user_id = v_uid and consent_type = 'health' and revoked_at is null;
    delete from public.body_measurements where member_id = v_uid;
    get diagnostics v_n = row_count;
    perform private.audit('health_consent_revoke', 'consents', v_uid::text,
      jsonb_build_object('deleted_measurements', v_n));
  end if;

  return private.has_health_consent(v_uid);
end;
$$;

-- RPC: üyenin rıza durumu (üyenin kendisi, yönetici veya üyenin eğitmeni sorabilir)
create or replace function public.member_health_consent(p_member_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or private.user_role() is null or p_member_id is null then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_member_id <> auth.uid() and not private.can_coach_member(p_member_id) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return private.has_health_consent(p_member_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on function private.has_health_consent(uuid), private.require_health_consent()
  from public, anon, authenticated;
revoke all on function private.handle_new_user() from public, anon, authenticated;
revoke all on function public.set_health_consent(boolean, text), public.member_health_consent(uuid)
  from public, anon;
grant execute on function public.set_health_consent(boolean, text), public.member_health_consent(uuid)
  to authenticated;
