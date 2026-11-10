-- Casper Training Studio — temel şema (tablolar, enumlar, kısıtlar, indeksler)
-- Kaynak: docs/DB_SCHEMA.md. İş kuralları: docs/BUSINESS_RULES.md

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Enumlar
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('member', 'trainer', 'admin');
create type public.package_status as enum ('active', 'expired', 'terminated');
create type public.class_type as enum ('individual', 'group');
create type public.class_status as enum ('scheduled', 'cancelled');
create type public.reservation_status as enum ('booked', 'cancelled', 'no_show');
create type public.credit_entry_type as enum
  ('grant', 'booking', 'refund', 'transfer_out', 'transfer_in', 'adjustment');
create type public.wallet_entry_type as enum
  ('topup', 'purchase', 'reversal', 'adjustment');
create type public.deletion_request_status as enum
  ('pending', 'processed', 'rejected');
create type public.notification_status as enum ('pending', 'sent', 'failed');

-- ---------------------------------------------------------------------------
-- Profiller ve roller
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null default '' check (char_length(full_name) <= 120),
  birth_date  date check (birth_date > date '1900-01-01'),
  height_cm   integer check (height_cm between 50 and 260),
  weight_kg   numeric(5,1) check (weight_kg between 20 and 400),
  role        public.user_role not null default 'member',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index profiles_role_idx on public.profiles (role);
create index profiles_full_name_idx on public.profiles (lower(full_name));

-- KVKK ve diğer onaylar (metin sürümü + tarih)
create table public.consents (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  consent_type  text not null default 'kvkk',
  text_version  text not null check (char_length(text_version) between 1 and 40),
  accepted_at   timestamptz not null default now(),
  unique (user_id, consent_type, text_version)
);

create table public.account_deletion_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  status        public.deletion_request_status not null default 'pending',
  note          text,
  requested_at  timestamptz not null default now(),
  processed_at  timestamptz,
  processed_by  uuid references public.profiles (id)
);
create unique index account_deletion_requests_one_pending
  on public.account_deletion_requests (user_id) where status = 'pending';

-- ---------------------------------------------------------------------------
-- Kategori ve paket tanımları
-- ---------------------------------------------------------------------------
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique check (char_length(name) between 1 and 60),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table public.package_definitions (
  id             uuid primary key default gen_random_uuid(),
  category_id    uuid not null references public.categories (id),
  name           text not null check (char_length(name) between 1 and 80),
  session_count  integer not null,
  validity_days  integer not null,
  price          numeric(12,2) not null check (price >= 0),
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- Yol haritası §6: 8/12 ders = 30 gün, 16/20 ders = 40 gün
  constraint package_definitions_validity_rule check (
    (session_count in (8, 12) and validity_days = 30)
    or (session_count in (16, 20) and validity_days = 40)
  )
);
create index package_definitions_category_idx
  on public.package_definitions (category_id);

-- ---------------------------------------------------------------------------
-- Üye paketleri
-- ---------------------------------------------------------------------------
create table public.member_packages (
  id                 uuid primary key default gen_random_uuid(),
  member_id          uuid not null references public.profiles (id),
  definition_id      uuid not null references public.package_definitions (id),
  category_id        uuid not null references public.categories (id),
  total_credits      integer not null check (total_credits > 0),
  remaining_credits  integer not null check (remaining_credits >= 0),
  price_paid         numeric(12,2) not null check (price_paid >= 0), -- atama anındaki fiyat
  activated_at       timestamptz not null default now(),
  ends_at            timestamptz not null,
  status             public.package_status not null default 'active',
  closed_at          timestamptz,
  replaced_by        uuid references public.member_packages (id),
  assigned_by        uuid references public.profiles (id),
  idempotency_key    uuid unique,
  created_at         timestamptz not null default now(),
  check (ends_at > activated_at)
);
-- Aynı kategoride tek aktif paket
create unique index member_packages_one_active_per_category
  on public.member_packages (member_id, category_id) where status = 'active';
create index member_packages_member_idx on public.member_packages (member_id);

-- Dondurma kayıtları: [starts_at, ends_at) aralığı
create table public.package_freezes (
  id                 uuid primary key default gen_random_uuid(),
  member_package_id  uuid not null references public.member_packages (id),
  starts_at          timestamptz not null,
  ends_at            timestamptz not null,
  days               integer not null check (days > 0),
  note               text,
  created_by         uuid not null references public.profiles (id),
  created_at         timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index package_freezes_package_idx
  on public.package_freezes (member_package_id, starts_at);

-- ---------------------------------------------------------------------------
-- Dersler
-- ---------------------------------------------------------------------------
create table public.classes (
  id            uuid primary key default gen_random_uuid(),
  trainer_id    uuid not null references public.profiles (id),
  category_id   uuid not null references public.categories (id),
  class_type    public.class_type not null,
  capacity      integer not null,
  booked_count  integer not null default 0,
  title         text check (char_length(title) <= 80),
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  status        public.class_status not null default 'scheduled',
  cancelled_at  timestamptz,
  cancelled_by  uuid references public.profiles (id),
  created_by    uuid not null references public.profiles (id),
  created_at    timestamptz not null default now(),
  check (ends_at > starts_at),
  -- Yol haritası §7: bireysel 1, grup 6
  constraint classes_capacity_rule check (
    (class_type = 'individual' and capacity = 1)
    or (class_type = 'group' and capacity = 6)
  ),
  -- Kontenjan asla aşılamaz (son savunma hattı)
  constraint classes_booked_within_capacity
    check (booked_count >= 0 and booked_count <= capacity)
);
create index classes_starts_at_idx on public.classes (starts_at);
create index classes_trainer_idx on public.classes (trainer_id, starts_at);
create index classes_category_idx on public.classes (category_id, starts_at);

-- ---------------------------------------------------------------------------
-- Rezervasyonlar
-- ---------------------------------------------------------------------------
create table public.reservations (
  id                 uuid primary key default gen_random_uuid(),
  class_id           uuid not null references public.classes (id),
  member_id          uuid not null references public.profiles (id),
  member_package_id  uuid not null references public.member_packages (id),
  status             public.reservation_status not null default 'booked',
  idempotency_key    uuid not null,
  booked_at          timestamptz not null default now(),
  booked_by          uuid not null references public.profiles (id),
  cancelled_at       timestamptz,
  cancelled_by       uuid references public.profiles (id),
  cancel_reason      text,
  credit_refunded    boolean not null default false,
  unique (member_id, idempotency_key)
);
-- Aynı derse ikinci (iptal edilmemiş) rezervasyon olamaz
create unique index reservations_one_live_per_class_member
  on public.reservations (class_id, member_id) where status <> 'cancelled';
create index reservations_member_idx on public.reservations (member_id, booked_at desc);
create index reservations_class_idx on public.reservations (class_id);
create index reservations_package_idx on public.reservations (member_package_id);

-- ---------------------------------------------------------------------------
-- Hak hareketleri (yalnızca ekleme; silme/güncelleme yok)
-- ---------------------------------------------------------------------------
create table public.credit_ledger (
  id                 bigint generated always as identity primary key,
  member_package_id  uuid not null references public.member_packages (id),
  member_id          uuid not null references public.profiles (id),
  entry_type         public.credit_entry_type not null,
  delta              integer not null check (delta <> 0),
  balance_after      integer not null check (balance_after >= 0),
  reservation_id     uuid references public.reservations (id),
  note               text,
  created_by         uuid references public.profiles (id),
  created_at         timestamptz not null default now()
);
-- Bir rezervasyon için en fazla bir düşüm ve bir iade
create unique index credit_ledger_one_booking_refund_per_reservation
  on public.credit_ledger (reservation_id, entry_type)
  where reservation_id is not null and entry_type in ('booking', 'refund');
create index credit_ledger_package_idx on public.credit_ledger (member_package_id, id);
create index credit_ledger_member_idx on public.credit_ledger (member_id, id);

-- ---------------------------------------------------------------------------
-- Ürünler, satışlar, cüzdan
-- ---------------------------------------------------------------------------
create table public.products (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  price       numeric(12,2) not null check (price >= 0),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.wallets (
  member_id   uuid primary key references public.profiles (id),
  balance     numeric(12,2) not null default 0 check (balance >= 0),
  updated_at  timestamptz not null default now()
);

create table public.sales (
  id               uuid primary key default gen_random_uuid(),
  member_id        uuid not null references public.profiles (id),
  product_id       uuid not null references public.products (id),
  seller_id        uuid not null references public.profiles (id),
  quantity         integer not null check (quantity > 0),
  unit_price       numeric(12,2) not null check (unit_price >= 0), -- satış anındaki fiyat
  total            numeric(12,2) not null check (total >= 0),
  idempotency_key  uuid not null unique,
  reversed_at      timestamptz,
  reversed_by      uuid references public.profiles (id),
  created_at       timestamptz not null default now()
);
create index sales_member_idx on public.sales (member_id, created_at desc);
create index sales_seller_idx on public.sales (seller_id, created_at desc);

-- Cüzdan hareketleri (yalnızca ekleme)
create table public.wallet_ledger (
  id                 bigint generated always as identity primary key,
  member_id          uuid not null references public.profiles (id),
  entry_type         public.wallet_entry_type not null,
  amount             numeric(12,2) not null check (amount <> 0), -- + giriş, - çıkış
  balance_after      numeric(12,2) not null check (balance_after >= 0),
  sale_id            uuid references public.sales (id),
  reverses_entry_id  bigint unique references public.wallet_ledger (id), -- bir kayıt bir kez ters çevrilir
  note               text,
  idempotency_key    uuid not null unique,
  created_by         uuid not null references public.profiles (id),
  created_at         timestamptz not null default now()
);
create index wallet_ledger_member_idx on public.wallet_ledger (member_id, id desc);

-- ---------------------------------------------------------------------------
-- İşlem kayıtları ve bildirimler
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid references public.profiles (id),
  action      text not null,
  entity      text not null,
  entity_id   text,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index audit_log_entity_idx on public.audit_log (entity, entity_id);
create index audit_log_created_idx on public.audit_log (created_at desc);

create table public.device_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  token         text not null unique,
  platform      text not null check (platform in ('ios', 'android')),
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  kind        text not null,
  title       text not null,
  body        text not null,
  payload     jsonb not null default '{}'::jsonb,
  dedupe_key  text not null unique, -- aynı bildirim iki kez gönderilmez
  status      public.notification_status not null default 'pending',
  error       text,
  sent_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
