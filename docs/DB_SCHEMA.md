# Veritabanı Şeması

Veritabanının tek doğru kaynağı `supabase/migrations/` klasöründeki SQL dosyalarıdır; bu belge onların özetidir. İş kuralı içeren tüm yazmalar (paket, ders, rezervasyon, hak, cüzdan, rol) `SECURITY DEFINER` RPC fonksiyonları üzerinden yapılır ve bu fonksiyonlar `search_path = ''` ile tanımlıdır; doğrudan tablo yazımı yalnızca RLS özetinde belirtilen tablolarda mümkündür. Açık kararların varsayılanları: `docs/BUSINESS_RULES.md`. `private` şeması API'ye (PostgREST) açık değildir; yardımcı fonksiyonlar ve kilit mantığı orada yaşar.

Aksi belirtilmedikçe yabancı anahtarlarda `ON DELETE` yoktur (`NO ACTION`). Tablo satırlarındaki "kısıt" adı verilmeyen CHECK ve UNIQUE tanımları Postgres'in ürettiği varsayılan adla saklanır.

## Enumlar

| enum | değerler |
|---|---|
| `user_role` | `member`, `trainer`, `admin` |
| `package_status` | `active`, `expired`, `terminated` |
| `class_type` | `individual`, `group` |
| `class_status` | `scheduled`, `cancelled` |
| `reservation_status` | `booked`, `cancelled`, `no_show` |
| `credit_entry_type` | `grant`, `booking`, `refund`, `transfer_out`, `transfer_in`, `adjustment` |
| `wallet_entry_type` | `topup`, `purchase`, `reversal`, `adjustment` |
| `deletion_request_status` | `pending`, `processed`, `rejected` |
| `notification_status` | `pending`, `sent`, `failed` |

## Tablolar

### profiles
Her auth kullanıcısının profili; rol ve aktiflik burada tutulur. Satır yalnızca `auth.users` tetikleyicisiyle oluşur.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK; FK → `auth.users(id)` ON DELETE CASCADE |
| full_name | text | NOT NULL, default `''`; CHECK uzunluk ≤ 120 |
| birth_date | date | NULL; CHECK > 1900-01-01 |
| height_cm | integer | NULL; CHECK 50–260 |
| weight_kg | numeric(5,1) | NULL; CHECK 20–400 |
| role | user_role | NOT NULL, default `member` |
| is_active | boolean | NOT NULL, default `true` |
| created_at | timestamptz | NOT NULL, default `now()` |
| updated_at | timestamptz | NOT NULL, default `now()`; `profiles_touch` tetikleyicisi günceller |

- Kısıtlar: PK(`id`); boy, kilo, doğum tarihi CHECK'leri (adsız).
- İndeksler: `profiles_role_idx` (role), `profiles_full_name_idx` (lower(full_name)).

### consents
Onay kayıtları (KVKK). Aynı metin sürümü bir kullanıcı için bir kez kaydedilir.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| user_id | uuid | NOT NULL; FK → `profiles(id)` ON DELETE CASCADE |
| consent_type | text | NOT NULL, default `'kvkk'` |
| text_version | text | NOT NULL; CHECK uzunluk 1–40 |
| accepted_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`user_id`, `consent_type`, `text_version`) (adsız).
- İndeksler: yalnızca UNIQUE'in dolaylı indeksi.

### account_deletion_requests
Hesap silme talepleri. Bir kullanıcının aynı anda yalnızca bir bekleyen talebi olabilir.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| user_id | uuid | NOT NULL; FK → `profiles(id)` ON DELETE CASCADE |
| status | deletion_request_status | NOT NULL, default `pending` |
| note | text | NULL |
| requested_at | timestamptz | NOT NULL, default `now()` |
| processed_at | timestamptz | NULL |
| processed_by | uuid | NULL; FK → `profiles(id)` |

- Kısıtlar: partial UNIQUE `account_deletion_requests_one_pending` (`user_id`) WHERE `status = 'pending'`.
- İndeksler: `account_deletion_requests_one_pending`.

### categories
Ders/paket kategorileri (ör. bireysel, grup).

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| name | text | NOT NULL, UNIQUE; CHECK uzunluk 1–60 |
| is_active | boolean | NOT NULL, default `true` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`name`) ve CHECK (adsız).
- İndeksler: UNIQUE'in dolaylı indeksi.

### package_definitions
Yönetici tarafından tanımlanan paket şablonları.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| category_id | uuid | NOT NULL; FK → `categories(id)` |
| name | text | NOT NULL; CHECK uzunluk 1–80 |
| session_count | integer | NOT NULL (8, 12, 16 veya 20 olmalı, bkz. kısıt) |
| validity_days | integer | NOT NULL (session_count ile birlikte kontrol edilir) |
| price | numeric(12,2) | NOT NULL; CHECK ≥ 0 |
| is_active | boolean | NOT NULL, default `true` |
| created_at | timestamptz | NOT NULL, default `now()` |
| updated_at | timestamptz | NOT NULL, default `now()`; `package_definitions_touch` günceller |

- Kısıtlar: CHECK `package_definitions_validity_rule` — (session_count 8 veya 12 ve validity_days 30) veya (session_count 16 veya 20 ve validity_days 40).
- İndeksler: `package_definitions_category_idx` (category_id).

### member_packages
Üyeye atanmış paketler (hak havuzu). Aynı üyenin aynı kategoride yalnızca bir aktif paketi olabilir.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| member_id | uuid | NOT NULL; FK → `profiles(id)` |
| definition_id | uuid | NOT NULL; FK → `package_definitions(id)` |
| category_id | uuid | NOT NULL; FK → `categories(id)` |
| total_credits | integer | NOT NULL; CHECK > 0 |
| remaining_credits | integer | NOT NULL; CHECK ≥ 0 |
| price_paid | numeric(12,2) | NOT NULL; CHECK ≥ 0 (atama anındaki fiyat) |
| activated_at | timestamptz | NOT NULL, default `now()` |
| ends_at | timestamptz | NOT NULL |
| status | package_status | NOT NULL, default `active` |
| closed_at | timestamptz | NULL |
| replaced_by | uuid | NULL; FK → `member_packages(id)` |
| assigned_by | uuid | NULL; FK → `profiles(id)` |
| idempotency_key | uuid | NULL; UNIQUE |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: partial UNIQUE `member_packages_one_active_per_category` (`member_id`, `category_id`) WHERE `status = 'active'`; CHECK `ends_at > activated_at` (adsız); UNIQUE(`idempotency_key`) (adsız).
- İndeksler: `member_packages_one_active_per_category`, `member_packages_member_idx` (member_id).

### package_freezes
Paket dondurma kayıtları. Aralık yarı açıktır: [starts_at, ends_at).

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| member_package_id | uuid | NOT NULL; FK → `member_packages(id)` |
| starts_at | timestamptz | NOT NULL |
| ends_at | timestamptz | NOT NULL |
| days | integer | NOT NULL; CHECK > 0 |
| note | text | NULL |
| created_by | uuid | NOT NULL; FK → `profiles(id)` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: CHECK `ends_at > starts_at` (adsız); CHECK `days > 0` (adsız). Dondurma aralıklarının çakışmaz olması DB kısıtı değildir; `freeze_package` içinde `FREEZE_OVERLAP` ile kontrol edilir.
- İndeksler: `package_freezes_package_idx` (member_package_id, starts_at).

### classes
Ders oturumları. `booked_count` kontenjan sayacıdır.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| trainer_id | uuid | NOT NULL; FK → `profiles(id)` |
| category_id | uuid | NOT NULL; FK → `categories(id)` |
| class_type | class_type | NOT NULL |
| capacity | integer | NOT NULL |
| booked_count | integer | NOT NULL, default `0` |
| title | text | NULL; CHECK uzunluk ≤ 80 |
| starts_at | timestamptz | NOT NULL |
| ends_at | timestamptz | NOT NULL; CHECK `ends_at > starts_at` (adsız) |
| status | class_status | NOT NULL, default `scheduled` |
| cancelled_at | timestamptz | NULL |
| cancelled_by | uuid | NULL; FK → `profiles(id)` |
| created_by | uuid | NOT NULL; FK → `profiles(id)` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: CHECK `classes_capacity_rule` — (individual ve capacity 1) veya (group ve capacity 6); CHECK `classes_booked_within_capacity` — 0 ≤ booked_count ≤ capacity.
- İndeksler: `classes_starts_at_idx` (starts_at), `classes_trainer_idx` (trainer_id, starts_at), `classes_category_idx` (category_id, starts_at).

### reservations
Üyenin derse kaydı. İptal edilen kayıt satırda kalır (status = `cancelled`).

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| class_id | uuid | NOT NULL; FK → `classes(id)` |
| member_id | uuid | NOT NULL; FK → `profiles(id)` |
| member_package_id | uuid | NOT NULL; FK → `member_packages(id)` |
| status | reservation_status | NOT NULL, default `booked` |
| idempotency_key | uuid | NOT NULL |
| booked_at | timestamptz | NOT NULL, default `now()` |
| booked_by | uuid | NOT NULL; FK → `profiles(id)` |
| cancelled_at | timestamptz | NULL |
| cancelled_by | uuid | NULL; FK → `profiles(id)` |
| cancel_reason | text | NULL |
| credit_refunded | boolean | NOT NULL, default `false` |

- Kısıtlar: UNIQUE(`member_id`, `idempotency_key`) (adsız); partial UNIQUE `reservations_one_live_per_class_member` (`class_id`, `member_id`) WHERE `status <> 'cancelled'` (`no_show` de "canlı" sayılır).
- İndeksler: `reservations_one_live_per_class_member`, `reservations_member_idx` (member_id, booked_at DESC), `reservations_class_idx` (class_id), `reservations_package_idx` (member_package_id).

### credit_ledger
Paket hak hareketleri. Yalnızca ekleme; güncelleme ve silme yetkisi yoktur.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | bigint | PK, `GENERATED ALWAYS AS IDENTITY` |
| member_package_id | uuid | NOT NULL; FK → `member_packages(id)` |
| member_id | uuid | NOT NULL; FK → `profiles(id)` |
| entry_type | credit_entry_type | NOT NULL |
| delta | integer | NOT NULL; CHECK ≠ 0 |
| balance_after | integer | NOT NULL; CHECK ≥ 0 |
| reservation_id | uuid | NULL; FK → `reservations(id)` |
| note | text | NULL |
| created_by | uuid | NULL; FK → `profiles(id)` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: partial UNIQUE `credit_ledger_one_booking_refund_per_reservation` (`reservation_id`, `entry_type`) WHERE `reservation_id IS NOT NULL AND entry_type IN ('booking', 'refund')`.
- İndeksler: `credit_ledger_one_booking_refund_per_reservation`, `credit_ledger_package_idx` (member_package_id, id), `credit_ledger_member_idx` (member_id, id).

### products
Satılabilir ürünler (yönetici tanımlar).

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| name | text | NOT NULL; CHECK uzunluk 1–80 |
| price | numeric(12,2) | NOT NULL; CHECK ≥ 0 |
| is_active | boolean | NOT NULL, default `true` |
| created_at | timestamptz | NOT NULL, default `now()` |
| updated_at | timestamptz | NOT NULL, default `now()`; `products_touch` günceller |

- Kısıtlar: CHECK'ler (adsız).
- İndeksler: yok (PK dışında).

### wallets
Üye cüzdanı; bakiye TL cinsindendir. Satır kayıt tetikleyicisinde veya ilk kilitlemede oluşur.

| sütun | tip | kural/varsayılan |
|---|---|---|
| member_id | uuid | PK; FK → `profiles(id)` |
| balance | numeric(12,2) | NOT NULL, default `0`; CHECK ≥ 0 (adsız) |
| updated_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: PK; CHECK `balance >= 0` (adsız).
- İndeksler: PK.

### sales
Ürün satışları. `total` değeri `unit_price * quantity` olarak `sell_product` içinde hesaplanır (DB'de bu bağıntıyı zorlayan CHECK yoktur).

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| member_id | uuid | NOT NULL; FK → `profiles(id)` |
| product_id | uuid | NOT NULL; FK → `products(id)` |
| seller_id | uuid | NOT NULL; FK → `profiles(id)` |
| quantity | integer | NOT NULL; CHECK > 0 |
| unit_price | numeric(12,2) | NOT NULL; CHECK ≥ 0 (satış anındaki fiyat) |
| total | numeric(12,2) | NOT NULL; CHECK ≥ 0 |
| idempotency_key | uuid | NOT NULL; UNIQUE (adsız) |
| reversed_at | timestamptz | NULL |
| reversed_by | uuid | NULL; FK → `profiles(id)` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`idempotency_key`) (adsız); CHECK'ler (adsız).
- İndeksler: `sales_member_idx` (member_id, created_at DESC), `sales_seller_idx` (seller_id, created_at DESC).

### wallet_ledger
Cüzdan hareketleri. Yalnızca ekleme; ters çevirme ayrı bir kayıtla yapılır.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | bigint | PK, `GENERATED ALWAYS AS IDENTITY` |
| member_id | uuid | NOT NULL; FK → `profiles(id)` |
| entry_type | wallet_entry_type | NOT NULL |
| amount | numeric(12,2) | NOT NULL; CHECK ≠ 0 (+ giriş, − çıkış) |
| balance_after | numeric(12,2) | NOT NULL; CHECK ≥ 0 |
| sale_id | uuid | NULL; FK → `sales(id)` |
| reverses_entry_id | bigint | NULL; UNIQUE; FK → `wallet_ledger(id)` |
| note | text | NULL |
| idempotency_key | uuid | NOT NULL; UNIQUE (adsız) |
| created_by | uuid | NOT NULL; FK → `profiles(id)` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`reverses_entry_id`) (adsız) — bir hareket en fazla bir kez ters çevrilir; UNIQUE(`idempotency_key`) (adsız); CHECK'ler (adsız).
- İndeksler: `wallet_ledger_member_idx` (member_id, id DESC); UNIQUE'lerin dolaylı indeksleri.

### audit_log
Yönetici işlemlerinin denetim kaydı. Yazma yalnızca `private.audit()` üzerinden yapılır.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | bigint | PK, `GENERATED ALWAYS AS IDENTITY` |
| actor_id | uuid | NULL; FK → `profiles(id)` |
| action | text | NOT NULL |
| entity | text | NOT NULL |
| entity_id | text | NULL (tip metin; uuid ya da bigint değerleri metin olarak tutulur) |
| details | jsonb | NOT NULL, default `'{}'` |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: yok (PK dışında).
- İndeksler: `audit_log_entity_idx` (entity, entity_id), `audit_log_created_idx` (created_at DESC).

### device_tokens
Push bildirimi cihaz token'ları. Üye kendi token'larını doğrudan yönetebilir.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| user_id | uuid | NOT NULL; FK → `profiles(id)` ON DELETE CASCADE |
| token | text | NOT NULL; UNIQUE (adsız) |
| platform | text | NOT NULL; CHECK `platform IN ('ios', 'android')` (adsız) |
| created_at | timestamptz | NOT NULL, default `now()` |
| last_seen_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`token`) (adsız); CHECK platform (adsız).
- İndeksler: `device_tokens_user_idx` (user_id); UNIQUE'in dolaylı indeksi.

### notifications
Bildirim kuyruğu/geçmişi. `dedupe_key` aynı bildirimin iki kez eklenmesini engeller.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` |
| user_id | uuid | NOT NULL; FK → `profiles(id)` ON DELETE CASCADE |
| kind | text | NOT NULL |
| title | text | NOT NULL |
| body | text | NOT NULL |
| payload | jsonb | NOT NULL, default `'{}'` |
| dedupe_key | text | NOT NULL; UNIQUE (adsız) |
| status | notification_status | NOT NULL, default `pending` |
| error | text | NULL |
| sent_at | timestamptz | NULL |
| created_at | timestamptz | NOT NULL, default `now()` |

- Kısıtlar: UNIQUE(`dedupe_key`) (adsız).
- İndeksler: `notifications_user_idx` (user_id, created_at DESC).

## Bütünlük garantileri

- **Tek aktif paket:** partial UNIQUE `member_packages_one_active_per_category` (member_id, category_id WHERE status = 'active').
- **Çift rezervasyon engeli:** partial UNIQUE `reservations_one_live_per_class_member` (class_id, member_id WHERE status <> 'cancelled'); ayrıca `book_class` içinde `ALREADY_BOOKED` kontrolü.
- **Kontenjan aşılamaz:** `book_class` ders satırını `FOR UPDATE` ile kilitler ve `CLASS_FULL` kontrolü yapar; son savunma hattı CHECK `classes_booked_within_capacity`.
- **Hak eksiye düşmez:** `book_class` paket satırını `FOR UPDATE` ile kilitler (`NO_CREDITS` kontrolü); son savunma hattı CHECK `remaining_credits >= 0`.
- **Tek düşüm / tek iade:** partial UNIQUE `credit_ledger_one_booking_refund_per_reservation` (reservation_id, entry_type WHERE entry_type IN ('booking', 'refund')).
- **Bakiye eksiye düşmez:** `wallets` satırı `FOR UPDATE` ile kilitlenir (`private.lock_wallet`, `private.wallet_apply`); son savunma hattı CHECK `wallets.balance >= 0`.
- **İdempotency anahtarları** (tekrarlanan istek ikinci kayıt yaratmaz):
  - `member_packages.idempotency_key` (UNIQUE, nullable) — `assign_package`
  - `reservations (member_id, idempotency_key)` (UNIQUE) — `book_class`
  - `sales.idempotency_key` (UNIQUE) — `sell_product`
  - `wallet_ledger.idempotency_key` (UNIQUE) — `admin_wallet_topup`, `admin_wallet_adjust`, `admin_reverse_wallet_entry`, `sell_product` (satış hareketi)
  - `consents (user_id, consent_type, text_version)` (UNIQUE) — `accept_kvkk` (`ON CONFLICT DO NOTHING`)
  - `notifications.dedupe_key` (UNIQUE) — bildirim tekilliği
- **Bir hareket bir kez ters çevrilir:** `wallet_ledger.reverses_entry_id` UNIQUE; ters kayıt ters çevrilemez (`CANNOT_REVERSE_REVERSAL`).
- **Kilit sırası** (`20261110120200_rpc_packages_classes_reservations.sql`, dosya başlığı):
  1. üye danışma kilidi (`private.lock_member`)
  2. `classes` satır(lar)ı — birden fazlaysa id sırasıyla
  3. `member_packages` / `reservations` satırları

  Bir fonksiyon sıradaki adımı atlayabilir, geriye dönemez. `reservations` satırları yalnızca ilgili dersin satır kilidi tutulurken değiştirilir; bu yüzden 3. adımdaki iki tablo arasındaki sıra kilitlenmeye yol açmaz.

## RLS özeti

Tüm tablolarda RLS açıktır. `anon` rolü hiçbir tabloya, dizinin kullanımına, fonksiyona veya `private` şemasına erişemez. `authenticated` için varsayılan yetkiler kaldırılmış, yalnızca gerekenler verilmiştir.

`profiles` için kolon bazlı yetki: üye ve yönetici yalnızca `full_name`, `birth_date`, `height_cm`, `weight_kg` kolonlarını güncelleyebilir. `role` ve `is_active` istemciden yazılamaz; bunlar yalnızca `admin_set_role` ve `admin_set_active` RPC'leri ile değişir.

| tablo | SELECT kimler | INSERT / UPDATE / DELETE kimler |
|---|---|---|
| profiles | kendi satırı veya admin | UPDATE: kendi satırı veya admin (yalnızca 4 kolon); INSERT/DELETE yok (yalnızca tetikleyici) |
| consents | kendi satırı veya admin | yalnızca RPC (`accept_kvkk`, kayıt tetikleyicisi) |
| account_deletion_requests | kendi satırı veya admin | INSERT: kendi adına, `pending` ve işlem alanları boş; UPDATE: yalnızca admin (status, note, processed_at, processed_by); DELETE yok |
| categories | aktif olanlar herkese, tümü admin; üye ayrıca kendi paketinin kategorisini (pasif olsa da) | INSERT/UPDATE/DELETE: yalnızca admin |
| package_definitions | aktif olanlar herkese, tümü admin; üye ayrıca kendi paketinin tanımını (pasif olsa da) | INSERT/UPDATE/DELETE: yalnızca admin |
| products | aktif olanlar herkese, tümü admin | INSERT/UPDATE/DELETE: yalnızca admin |
| member_packages | kendi satırı veya admin | yalnızca RPC |
| package_freezes | admin veya paketin sahibi | yalnızca RPC |
| classes | giriş yapmış herkes | yalnızca RPC |
| reservations | sahibi, admin veya dersin eğitmeni | yalnızca RPC |
| credit_ledger | kendi satırı veya admin | yalnızca RPC (yalnızca ekleme) |
| wallets | kendi satırı veya admin | yalnızca RPC |
| sales | sahibi (üye), admin veya satışı yapan (seller) | yalnızca RPC |
| wallet_ledger | kendi satırı veya admin | yalnızca RPC (yalnızca ekleme) |
| audit_log | yalnızca admin | yalnızca RPC (`private.audit`) |
| device_tokens | yalnızca sahibi | INSERT/UPDATE/DELETE: yalnızca sahibi (doğrudan) |
| notifications | sahibi veya admin | yalnızca RPC / service_role (henüz RPC yok) |

## RPC fonksiyonları

### A. Yazıldı (bu migration'larda)

Tüm fonksiyonlar `public` şemasındadır, `SECURITY DEFINER` ve `search_path = ''` ile tanımlıdır; `EXECUTE` yalnızca `authenticated` rolüne verilmiştir. Yetki kontrolleri fonksiyon içinde yapılır.

| fonksiyon imzası | kim çağırabilir | ne yapar | idempotency |
|---|---|---|---|
| `admin_set_role(p_user_id uuid, p_role user_role)` → profiles | admin | Kullanıcının rolünü değiştirir; admin kendi rolünü düşüremez; denetim kaydı yazar | yok (aynı değer tekrar yazılır, denetim satırı tekrar eklenir) |
| `admin_set_active(p_user_id uuid, p_is_active boolean)` → profiles | admin | Hesabı aktif/pasif yapar; admin kendini pasifleştiremez; denetim kaydı yazar | yok |
| `accept_kvkk(p_text_version text)` → consents | giriş yapmış kullanıcı | Kendi adına KVKK metin sürümü onayı kaydeder | UNIQUE (user_id, consent_type, text_version) ile ON CONFLICT DO NOTHING |
| `list_trainers()` → table(id, full_name) | giriş yapmış kullanıcı | Aktif eğitmenlerin id ve adını listeler | okuma (gerekmez) |
| `search_members(p_query text default '')` → table(id, full_name) | trainer, admin | Aktif üyeleri ada göre arar (en fazla 50); boy, kilo, doğum tarihi dönmez | okuma |
| `class_participants(p_class_id uuid)` → table(reservation_id, member_id, full_name, status, booked_at) | admin veya dersin eğitmeni | İptal edilmemiş katılımcıları listeler | okuma |
| `assign_package(p_member_id, p_definition_id, p_idempotency_key uuid, p_replace_existing boolean default false)` → member_packages | admin | Üyeye paket atar; eski aktif paket varsa kapatır (`p_replace_existing` gerekir), gelecekteki rezervasyonları yeni pakete aktarır ya da iade ile iptal eder | member_packages.idempotency_key (UNIQUE); aynı anahtar aynı paketi döndürür, farklı üye/tanımda `IDEMPOTENCY_KEY_REUSED` |
| `freeze_package(p_package_id uuid, p_start_date date, p_end_date date, p_note text default null)` → package_freezes | admin | Paketi İstanbul günlerine göre (uçlar dahil) dondurur; aralıktaki rezervasyonları iade ile iptal eder; `ends_at` değerini dondurma gün sayısı kadar uzatır; denetim kaydı yazar | yok (çakışma `FREEZE_OVERLAP` ile engellenir) |
| `create_class(p_category_id, p_class_type class_type, p_starts_at timestamptz, p_duration_minutes integer default 60, p_title text default null, p_trainer_id uuid default null)` → classes | trainer (kendi adına), admin (`p_trainer_id` zorunlu) | Ders oluşturur; kapasiteyi türe göre atar (bireysel 1, grup 6); eğitmenin çakışan dersi varsa reddeder | yok |
| `cancel_class(p_class_id uuid, p_refund boolean default true, p_reason text default null)` → classes | trainer (kendi dersi, başlamadan), admin | Dersi iptal eder ve aktif rezervasyonları iptal eder; trainer her zaman iade eder, admin `p_refund` ile seçer | zaten iptal edilmiş dersi mevcut kayıtla döndürür |
| `book_class(p_class_id uuid, p_idempotency_key uuid, p_member_id uuid default null)` → reservations | üye (kendi adına), admin (`p_member_id` ile) | Kontenjan, durum, paket geçerliliği, dondurma ve hak kontrolü yapar; rezervasyon, hak düşümü ve `booked_count` artışını tek transaction'da yapar | UNIQUE (member_id, idempotency_key); aynı anahtar aynı rezervasyonu döndürür, farklı derste `IDEMPOTENCY_KEY_REUSED` |
| `cancel_reservation(p_reservation_id uuid, p_refund boolean default null, p_reason text default null)` → reservations | üye (kendi rezervasyonu, dersten en az 2 saat önce), admin (her zaman) | Rezervasyonu iptal eder; üye için hak iade edilir; admin `p_refund` vermek zorundadır (`REFUND_CHOICE_REQUIRED`) | zaten iptal edilmişse mevcut kaydı döndürür |
| `admin_wallet_topup(p_member_id uuid, p_amount numeric, p_idempotency_key uuid, p_note text default null)` → wallet_ledger | admin | Üyenin cüzdanına yükleme yapar (0 < tutar ≤ 1.000.000, en fazla 2 ondalık); ödeme yöntemi kaydı tutulmaz | wallet_ledger.idempotency_key (UNIQUE); farklı üye/tür/tutarda `IDEMPOTENCY_KEY_REUSED` |
| `admin_wallet_adjust(p_member_id uuid, p_amount numeric, p_note text, p_idempotency_key uuid)` → wallet_ledger | admin | Artı veya eksi düzeltme hareketi yazar; not zorunludur; bakiye eksiye düşemez | wallet_ledger.idempotency_key (UNIQUE) |
| `sell_product(p_member_id uuid, p_product_id uuid, p_quantity integer, p_idempotency_key uuid)` → sales | trainer, admin | Üyenin cüzdanından ürün satar (1–100 adet); fiyat sunucuda işlem anındaki değerden alınır; satış ve `purchase` hareketi yazılır | sales.idempotency_key (UNIQUE); satış hareketi aynı anahtarı kullanır |
| `admin_reverse_wallet_entry(p_entry_id bigint, p_idempotency_key uuid, p_note text default null)` → wallet_ledger | admin | Bir cüzdan hareketini `reversal` ile ters çevirir; satış hareketiyse `sales.reversed_at` değerini işaretler | wallet_ledger.idempotency_key (UNIQUE); `reverses_entry_id` farklıysa `IDEMPOTENCY_KEY_REUSED` |

### B. private yardımcılar

Bu fonksiyonlar `private` şemasındadır; `public`, `anon` ve `authenticated` rollerine kapalıdır (yalnızca üç rol kontrolü `authenticated` ve `service_role` için açıktır).

| fonksiyon | amaç |
|---|---|
| `private.user_role()` | Oturumdaki kullanıcının rolünü döndürür; pasif hesapta null |
| `private.is_admin()` | Oturum admin ise true (RLS politikalarında kullanılır) |
| `private.is_staff()` | Oturum admin veya trainer ise true (RLS politikalarında kullanılır) |
| `private.require_admin()` | Admin değilse `FORBIDDEN` fırlatır; admin'in id'sini döndürür |
| `private.audit(action, entity, entity_id, details)` | `audit_log` tablosuna kayıt ekler |
| `private.safe_date(text)` | Metni date'e çevirir; hatalıysa null (kayıt olurken metadata için) |
| `private.safe_numeric(text)` | Metni numeric'e çevirir; hatalıysa null |
| `private.handle_new_user()` | `auth.users` tetikleyicisi: profil (rol her zaman `member`), cüzdan ve KVKK onayı oluşturur |
| `private.touch_updated_at()` | `updated_at` alanını `now()` ile günceller (profiles, package_definitions, products) |
| `private.lock_member(member_id)` | Üye bazlı advisory transaction kilidi |
| `private.cancel_reservation_core(...)` | Rezervasyon iptalinin çekirdeği; çağıran dersin kilidini tutmalıdır; iade varsa hak ve ledger yazar |
| `private.lock_wallet(member_id)` | Cüzdan satırını kilitler (yoksa oluşturur) ve bakiyeyi döndürür |
| `private.wallet_apply(...)` | Cüzdan bakiyesini değiştirir, bakiye eksiye düşerse `INSUFFICIENT_BALANCE`, hareket kaydı yazar |

### C. Planlanan (sonraki adımlar)

Bu fonksiyon ve süreçler henüz migration'da yoktur.

| ad | amaç | adım |
|---|---|---|
| `admin_adjust_credits` | Paket hakkında manuel düzeltme (`adjustment` ledger kaydı) | 5 |
| `mark_no_show` | Katılmayan üyenin rezervasyonunu `no_show` yapma | 5 |
| `unfreeze_package` | Dondurmayı erken bitirme | 5 |
| süresi dolan paketleri `expired` yapan zamanlanmış görev | Şu an süre kontrolü `ends_at` üzerinden anlık yapılır; statü güncellemesi yapılmaz | 5 |
| `request_account_deletion` süreci | Hesap silme talebi akışı (`account_deletion_requests`) | 8 |
| `register_device_token` + bildirim kuyruğu Edge Function | Token kaydı ve `notifications` kuyruğunun gönderimi | 7 |

## Hata kodları

Hatalar `raise exception 'KOD'` ile fırlatılır; istemci kodu metne göre Türkçe mesaj gösterir. `errcode` belirtilmemişse Postgres varsayılanı (P0001) geçerlidir.

| kod | anlamı |
|---|---|
| `FORBIDDEN` | Yetkisiz işlem (admin, trainer veya sahiplik şartı sağlanmadı) |
| `UNAUTHENTICATED` | Oturum açılmamış |
| `USER_NOT_FOUND` | Kullanıcı bulunamadı |
| `CANNOT_DEMOTE_SELF` | Admin kendi rolünü admin dışına düşüremez |
| `CANNOT_DEACTIVATE_SELF` | Admin kendi hesabını pasifleştiremez |
| `INVALID_VERSION` | KVKK metin sürümü geçersiz (1–40 karakter olmalı) |
| `IDEMPOTENCY_KEY_REQUIRED` | İdempotency anahtarı gönderilmedi |
| `IDEMPOTENCY_KEY_REUSED` | Aynı anahtar farklı bir istekte kullanılmış |
| `MEMBER_NOT_ELIGIBLE` | Üye aktif değil veya rolü member değil |
| `DEFINITION_NOT_FOUND` | Paket tanımı bulunamadı veya pasif |
| `ACTIVE_PACKAGE_EXISTS` | Aynı kategoride aktif paket var; yenileme için `p_replace_existing` gerekir |
| `RESERVATION_NOT_FOUND` | Rezervasyon bulunamadı (başkasınınki de bu kodla döner) |
| `INVALID_FREEZE_RANGE` | Dondurma tarih aralığı geçersiz (bitiş < başlangıç veya 365 günü aşıyor) |
| `FREEZE_IN_PAST` | Dondurma başlangıcı geçmişte |
| `PACKAGE_NOT_FOUND` | Paket bulunamadı |
| `PACKAGE_NOT_ACTIVE` | Paket aktif değil veya süresi dolmuş |
| `FREEZE_OUTSIDE_PACKAGE` | Dondurma paket geçerliliği dışında başlıyor |
| `FREEZE_OVERLAP` | Dondurma mevcut bir dondurma ile çakışıyor |
| `TRAINER_REQUIRED` | Admin ders açarken eğitmen belirtmedi |
| `TRAINER_NOT_FOUND` | Eğitmen bulunamadı, aktif değil veya trainer rolünde değil |
| `CATEGORY_NOT_FOUND` | Kategori bulunamadı veya pasif |
| `INVALID_CLASS_TIME` | Ders başlangıç zamanı geçersiz (boş veya geçmişte) |
| `INVALID_DURATION` | Ders süresi 15–240 dakika dışında |
| `TRAINER_BUSY` | Eğitmenin aynı saatte çakışan dersi var |
| `CLASS_NOT_FOUND` | Ders bulunamadı |
| `CLASS_ALREADY_STARTED` | Ders başlamış; işlem yapılamaz |
| `CLASS_CANCELLED` | Ders iptal edilmiş |
| `ALREADY_BOOKED` | Üyenin bu derste zaten canlı bir rezervasyonu var |
| `CLASS_FULL` | Ders kontenjanı dolu |
| `NO_ACTIVE_PACKAGE` | Üyenin bu kategoride aktif paketi yok |
| `PACKAGE_EXPIRED` | Paketin geçerlilik süresi dolmuş veya henüz başlamamış |
| `CLASS_AFTER_PACKAGE_END` | Ders tarihi paket bitiş tarihinden sonra |
| `PACKAGE_FROZEN` | Paket rezervasyon tarihinde veya şu an dondurulmuş |
| `NO_CREDITS` | Paketin kalan hakkı yok |
| `CANCEL_WINDOW_CLOSED` | Üye için iptal süresi (dersten 2 saat önce) geçmiş |
| `REFUND_CHOICE_REQUIRED` | Admin iptalinde iade tercihi (`p_refund`) belirtilmedi |
| `INSUFFICIENT_BALANCE` | Cüzdan bakiyesi yetersiz (veya düzeltme bakiyeyi eksiye düşürür) |
| `INVALID_AMOUNT` | Tutar geçersiz (sıfır, limit dışı veya ikiden fazla ondalık) |
| `NOTE_REQUIRED` | Düzeltme hareketinde açıklama boş |
| `INVALID_QUANTITY` | Satış adedi 1–100 dışında |
| `PRODUCT_NOT_FOUND` | Ürün bulunamadı veya pasif |
| `ENTRY_NOT_FOUND` | Cüzdan hareketi bulunamadı |
| `CANNOT_REVERSE_REVERSAL` | Ters kayıt tekrar ters çevrilemez |
| `ALREADY_REVERSED` | Hareket daha önce ters çevrilmiş |

## İlk yöneticiyi atama

Sistemde ilk yönetici, kayıt sonrası Supabase SQL Editor'den bir kez atanır (RPC'ler yalnızca mevcut bir admin tarafından çalıştırılabildiği için bu adım RPC ile yapılamaz):

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'yonetici@ornek.com');
```

Bundan sonra roller yalnızca `admin_set_role` RPC'si ile değiştirilir.

## Referans sistemi (adım 3b)

Kaynak: `20261111100000_referrals.sql`. Kurallar: `docs/BUSINESS_RULES.md` §13 (F-*).

**Enum:** `referral_status` = `pending`, `approved`, `rejected`.

**Değişen tablolar**

| tablo | sütun | tip | kural |
|---|---|---|---|
| profiles | referral_code | text | NOT NULL, UNIQUE (`profiles_referral_code_key`), CHECK `profiles_referral_code_format` (7 karakter, `ABCDEFGHJKMNPQRSTUVWXYZ23456789`); istemci yazamaz |
| member_packages | list_price | numeric(12,2) | NOT NULL, ≥ 0; atama anındaki liste fiyatı |
| member_packages | discount_percent | integer | NOT NULL, varsayılan 0, CHECK 0–50; uygulanan referans indirimi |
| member_packages | price_paid | numeric(12,2) | artık indirimli fiyat: `list_price × (100 − discount_percent) / 100` |

### referrals

Kim kimi getirdi ve yönetici kararı.

| sütun | tip | kural/varsayılan |
|---|---|---|
| id | uuid | PK, `gen_random_uuid()` |
| referrer_id | uuid | NOT NULL, FK profiles ON DELETE CASCADE (getiren / kod sahibi) |
| referred_id | uuid | NOT NULL, FK profiles ON DELETE CASCADE (getirilen) |
| code_used | text | NOT NULL |
| status | referral_status | NOT NULL, varsayılan `pending` |
| created_at | timestamptz | NOT NULL, `now()` |
| decided_at | timestamptz | |
| decided_by | uuid | FK profiles |
| decision_note | text | |

- Kısıtlar: `referrals_no_self` CHECK (`referrer_id <> referred_id`); `referrals_referred_once` UNIQUE (`referred_id`) — bir kişi bir kez referans alır.
- İndeksler: `referrals_referrer_idx` (referrer_id, status); `referrals_status_idx` (status, created_at desc).
- RLS: SELECT yalnızca admin (`referrals_select_admin`); yazma yalnızca RPC / kayıt tetikleyicisi. Üyeler yalnızca `my_referrals` ve `referral_summary` RPC'lerini kullanır.

**Fonksiyonlar**

| fonksiyon | kim | ne yapar |
|---|---|---|
| `referral_summary(p_user_id uuid default null)` → jsonb | kendi özeti herkes; başka kullanıcı için admin | `referral_code`, `active_count`, `discount_percent`, `approved_count`, `pending_count`, `was_referred` |
| `my_referrals()` → table(referral_id, display_name, status, counts_now, created_at) | giriş yapmış kullanıcı | Getirdiği kişiler; yalnızca "Ad S.", durum, şu an sayılıyor mu |
| `admin_list_referrals(p_status referral_status default null)` → table | admin | Panel listesi: getiren (ad, kod, güncel oran), getirilen (ad, aktif paketi var mı), durum, tarihler; en fazla 500 satır, bekleyenler önce |
| `admin_decide_referral(p_referral_id uuid, p_approve boolean, p_note text default null)` → referrals | admin | Onay / ret; aynı karar tekrarında mevcut kaydı döndürür; denetim kaydı yazar |
| `assign_package(p_member_id, p_definition_id, p_idempotency_key, p_replace_existing default false, p_discount_percent integer default 0)` → member_packages | admin | **İmza değişti** (eski 4 parametreli sürüm kaldırıldı). Oran 0–50 ve üyenin o anki hakkından büyük olamaz; `list_price`, `discount_percent`, `price_paid` kaydedilir |
| `private.generate_referral_code()` | — | 7 karakterlik rastgele kod |
| `private.has_usable_package(member_id)` | — | Üyenin şu an kullanılabilir (aktif, süresi dolmamış, dondurulmamış) paketi var mı |
| `private.active_referral_count(user_id)` / `private.referral_discount_percent(user_id)` | — | Sayılan referans sayısı / hak edilen oran (`least(sayı × 5, 50)`) |
| `private.short_name(full_name)` | — | "Ad S." gösterimi |
| `private.handle_new_user()` | — | **Güncellendi**: profil oluştururken referans kodu üretir (çakışmada yeniden dener); metadata içindeki `referral_code` geçerliyse `pending` referans ekler, geçersizse kaydı engellemez |

**Yeni hata kodları:** `INVALID_DISCOUNT` (oran 0–50 dışında), `DISCOUNT_EXCEEDS_ENTITLEMENT` (oran üyenin o anki hakkından büyük), `REFERRAL_NOT_FOUND`, `DECISION_REQUIRED`.

## Takvim okuma RPC'leri ve elle referans (adım 4)

Kaynak: `20261111110000_referral_manual_and_schedule_views.sql`. Tablo değişikliği yoktur.

| fonksiyon | kim | ne yapar |
|---|---|---|
| `list_classes(p_from timestamptz, p_to timestamptz, p_category_id uuid default null, p_trainer_id uuid default null, p_include_cancelled boolean default false)` → table | giriş yapmış aktif kullanıcı | Aralıktaki (en fazla 93 gün) dersler; eğitmen adı, kategori adı, kapasite, `booked_count`, çağıranın o dersteki canlı rezervasyonu (`my_reservation_id`); en fazla 1000 satır |
| `my_reservations()` → table | giriş yapmış kullanıcı | Kendi rezervasyonları (gelecek + geçmiş + iptal) ders, kategori ve eğitmen adıyla; en fazla 300 satır |
| `admin_class_reservations(p_class_id uuid)` → table | admin | Dersin tüm rezervasyonları (iptaller dahil): üye adı, durum, iade bilgisi, iptal nedeni |
| `admin_create_referral(p_referrer_id uuid, p_referred_id uuid, p_note text default null)` → referrals | admin | Elle referans ekler; doğrudan `approved`; `SELF_REFERRAL`, `REFERRAL_ALREADY_EXISTS`, `USER_NOT_FOUND`; denetim kaydı yazar |
| `admin_search_users(p_query text default '')` → table(id, full_name, role, referral_code) | admin | Aktif kullanıcıları ada veya tam referans koduna göre arar (en fazla 50) |
| `private.short_name(text)` | — | **Düzeltme:** `IMMUTABLE` yerine `STABLE` (lint uyarısı) |

Rezervasyon ve ders yazma işlemleri mevcut RPC'lerle yapılır: `create_class`, `cancel_class`, `book_class`, `cancel_reservation`, `class_participants`.

## Migration dosyaları

| dosya | içerik |
|---|---|
| `20261110120000_schema.sql` | enumlar, tablolar, kısıtlar, indeksler |
| `20261110120100_auth_roles_rls.sql` | kayıt tetikleyicisi, rol yardımcıları ve RPC'leri, RLS, yetkiler |
| `20261110120200_rpc_packages_classes_reservations.sql` | paket atama/yenileme, dondurma, ders, rezervasyon, iptal |
| `20261110120300_rpc_wallet.sql` | cüzdan ve ürün satışı |
| `20261111090000_package_read_policies.sql` | adım 3: üyenin kendi paketine bağlı pasif tanım/kategoriyi okuyabilmesi (`package_definitions_select_own_used`, `categories_select_own_used`), `member_packages_member_status_idx` indeksi |
| `20261111100000_referrals.sql` | adım 3b: referans kodu, `referrals` tablosu, sayım/indirim fonksiyonları, kayıt tetikleyicisi güncellemesi, `assign_package` indirim parametresi |
| `20261111110000_referral_manual_and_schedule_views.sql` | `short_name` STABLE düzeltmesi; elle referans (`admin_create_referral`, `admin_search_users`); takvim okuma RPC'leri (`list_classes`, `my_reservations`, `admin_class_reservations`) |
