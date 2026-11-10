-- Casper Training Studio — cüzdan ve ürün satışı RPC'leri
--
-- Eşzamanlılık: her işlem önce üyenin wallets satırını FOR UPDATE ile kilitler;
-- idempotency anahtarı kilit alındıktan SONRA kontrol edilir. Böylece
--   * eşzamanlı harcamalar bakiyeyi eksiye düşüremez (ayrıca CHECK balance >= 0),
--   * tekrarlanan istek ikinci hareket yaratmaz (ayrıca UNIQUE idempotency_key).
-- Hareketler silinmez/güncellenmez; hata düzeltmesi ters kayıt veya düzeltme ile yapılır.

-- Cüzdan satırını kilitler (yoksa oluşturur) ve güncel bakiyeyi döndürür
create or replace function private.lock_wallet(p_member_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_balance numeric(12,2);
begin
  if not exists (select 1 from public.profiles where id = p_member_id) then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  insert into public.wallets (member_id) values (p_member_id)
  on conflict (member_id) do nothing;
  select balance into v_balance from public.wallets
  where member_id = p_member_id for update;
  return v_balance;
end;
$$;

-- Ön koşul: çağıran private.lock_wallet ile kilidi almış olmalı
create or replace function private.wallet_apply(
  p_member_id uuid,
  p_entry_type public.wallet_entry_type,
  p_amount numeric,
  p_idempotency_key uuid,
  p_actor uuid,
  p_note text default null,
  p_sale_id uuid default null,
  p_reverses_entry_id bigint default null)
returns public.wallet_ledger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_balance numeric(12,2);
  v_entry   public.wallet_ledger;
begin
  select balance into v_balance from public.wallets where member_id = p_member_id for update;
  if v_balance + p_amount < 0 then
    raise exception 'INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  update public.wallets
  set balance = balance + p_amount, updated_at = now()
  where member_id = p_member_id
  returning balance into v_balance;

  insert into public.wallet_ledger
    (member_id, entry_type, amount, balance_after, sale_id, reverses_entry_id,
     note, idempotency_key, created_by)
  values
    (p_member_id, p_entry_type, p_amount, v_balance, p_sale_id, p_reverses_entry_id,
     p_note, p_idempotency_key, p_actor)
  returning * into v_entry;
  return v_entry;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bakiye yükleme (yalnızca yönetici). Ödeme yöntemi kaydı tutulmaz.
-- ---------------------------------------------------------------------------
create or replace function public.admin_wallet_topup(
  p_member_id uuid,
  p_amount numeric,
  p_idempotency_key uuid,
  p_note text default null)
returns public.wallet_ledger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_entry public.wallet_ledger;
begin
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount > 1000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT' using errcode = 'P0001';
  end if;

  perform private.lock_wallet(p_member_id);

  select * into v_entry from public.wallet_ledger where idempotency_key = p_idempotency_key;
  if found then
    if v_entry.member_id <> p_member_id or v_entry.entry_type <> 'topup'::public.wallet_entry_type
       or v_entry.amount <> p_amount then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_entry;
  end if;

  v_entry := private.wallet_apply(p_member_id, 'topup', p_amount, p_idempotency_key, v_admin, p_note);
  perform private.audit('wallet_topup', 'wallet_ledger', v_entry.id::text,
    jsonb_build_object('member_id', p_member_id, 'amount', p_amount));
  return v_entry;
end;
$$;

-- ---------------------------------------------------------------------------
-- Düzeltme hareketi (yalnızca yönetici): artı veya eksi tutar, açıklama zorunlu
-- ---------------------------------------------------------------------------
create or replace function public.admin_wallet_adjust(
  p_member_id uuid,
  p_amount numeric,
  p_note text,
  p_idempotency_key uuid)
returns public.wallet_ledger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := private.require_admin();
  v_entry public.wallet_ledger;
begin
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount = 0 or abs(p_amount) > 1000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT' using errcode = 'P0001';
  end if;
  if p_note is null or btrim(p_note) = '' then
    raise exception 'NOTE_REQUIRED' using errcode = 'P0001';
  end if;

  perform private.lock_wallet(p_member_id);

  select * into v_entry from public.wallet_ledger where idempotency_key = p_idempotency_key;
  if found then
    if v_entry.member_id <> p_member_id
       or v_entry.entry_type <> 'adjustment'::public.wallet_entry_type
       or v_entry.amount <> p_amount then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_entry;
  end if;

  v_entry := private.wallet_apply(p_member_id, 'adjustment', p_amount, p_idempotency_key,
                                  v_admin, btrim(p_note));
  perform private.audit('wallet_adjust', 'wallet_ledger', v_entry.id::text,
    jsonb_build_object('member_id', p_member_id, 'amount', p_amount));
  return v_entry;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ürün satışı (eğitmen veya yönetici). Fiyat sunucuda, işlem anındaki değerle alınır.
-- ---------------------------------------------------------------------------
create or replace function public.sell_product(
  p_member_id uuid,
  p_product_id uuid,
  p_quantity integer,
  p_idempotency_key uuid)
returns public.sales
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_product public.products;
  v_sale    public.sales;
  v_balance numeric(12,2);
  v_total   numeric(12,2);
begin
  if v_uid is null or not private.is_staff() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;
  if p_quantity is null or p_quantity not between 1 and 100 then
    raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_member_id and is_active and role = 'member'::public.user_role) then
    raise exception 'MEMBER_NOT_ELIGIBLE' using errcode = 'P0001';
  end if;

  v_balance := private.lock_wallet(p_member_id);

  -- Tekrarlanan istek: aynı satış iki kez işlenmez
  select * into v_sale from public.sales where idempotency_key = p_idempotency_key;
  if found then
    if v_sale.member_id <> p_member_id or v_sale.product_id <> p_product_id
       or v_sale.quantity <> p_quantity then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_sale;
  end if;

  select * into v_product from public.products where id = p_product_id and is_active;
  if not found then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_total := round(v_product.price * p_quantity, 2);
  if v_balance < v_total then
    raise exception 'INSUFFICIENT_BALANCE' using errcode = 'P0001';
  end if;

  insert into public.sales
    (member_id, product_id, seller_id, quantity, unit_price, total, idempotency_key)
  values
    (p_member_id, p_product_id, v_uid, p_quantity, v_product.price, v_total, p_idempotency_key)
  returning * into v_sale;

  if v_total > 0 then
    perform private.wallet_apply(p_member_id, 'purchase', -v_total, p_idempotency_key, v_uid,
                                 v_product.name || ' x' || p_quantity, v_sale.id);
  end if;
  return v_sale;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ters kayıt (yalnızca yönetici). Bir hareket en fazla bir kez ters çevrilir;
-- ters kaydın kendisi ters çevrilemez (gerekirse düzeltme hareketi girilir).
-- ---------------------------------------------------------------------------
create or replace function public.admin_reverse_wallet_entry(
  p_entry_id bigint,
  p_idempotency_key uuid,
  p_note text default null)
returns public.wallet_ledger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin    uuid := private.require_admin();
  v_original public.wallet_ledger;
  v_entry    public.wallet_ledger;
begin
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_original from public.wallet_ledger where id = p_entry_id;
  if not found then
    raise exception 'ENTRY_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform private.lock_wallet(v_original.member_id);

  select * into v_entry from public.wallet_ledger where idempotency_key = p_idempotency_key;
  if found then
    if v_entry.reverses_entry_id is distinct from p_entry_id then
      raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = 'P0001';
    end if;
    return v_entry;
  end if;

  if v_original.entry_type = 'reversal'::public.wallet_entry_type then
    raise exception 'CANNOT_REVERSE_REVERSAL' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.wallet_ledger where reverses_entry_id = p_entry_id) then
    raise exception 'ALREADY_REVERSED' using errcode = 'P0001';
  end if;

  -- Yüklemenin tersi bakiyeyi eksiye düşürecekse INSUFFICIENT_BALANCE döner
  v_entry := private.wallet_apply(
    v_original.member_id, 'reversal', -v_original.amount, p_idempotency_key, v_admin,
    coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Ters kayıt'),
    v_original.sale_id, p_entry_id);

  if v_original.sale_id is not null then
    update public.sales set reversed_at = now(), reversed_by = v_admin
    where id = v_original.sale_id;
  end if;

  perform private.audit('wallet_reverse', 'wallet_ledger', v_entry.id::text,
    jsonb_build_object('reverses', p_entry_id, 'amount', v_entry.amount));
  return v_entry;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler (son migration: genel süpürme + açık izinler)
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.admin_wallet_topup(uuid, numeric, uuid, text),
  public.admin_wallet_adjust(uuid, numeric, text, uuid),
  public.sell_product(uuid, uuid, integer, uuid),
  public.admin_reverse_wallet_entry(bigint, uuid, text)
from public, anon;
grant execute on function
  public.admin_wallet_topup(uuid, numeric, uuid, text),
  public.admin_wallet_adjust(uuid, numeric, text, uuid),
  public.sell_product(uuid, uuid, integer, uuid),
  public.admin_reverse_wallet_entry(bigint, uuid, text)
to authenticated;
