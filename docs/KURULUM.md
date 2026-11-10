# Kurulum ve Çalıştırma

## 1. Supabase projeleri (geliştirme ve canlı ayrı)

1. https://supabase.com üzerinde iki proje açın: `casper-dev` ve (yayına yakın) `casper-prod`.
2. Her projede **Authentication → URL Configuration**:
   - Site URL: `caspertraining://auth-callback`
   - Redirect URLs: `caspertraining://auth-callback`
3. **Authentication → Sign In / Providers → Email**: "Confirm email" açık olsun; en az şifre uzunluğu 8.

## 2. Migration dosyalarını çalıştırma

Supabase CLI ile (önerilen):

```bash
npm i -g supabase            # veya: scoop install supabase
supabase login
supabase link --project-ref <DEV_PROJE_REF>
supabase db push             # supabase/migrations/*.sql dosyalarını sırayla uygular
```

CLI yoksa: Supabase panelinde **SQL Editor** içine `supabase/migrations/` klasöründeki dosyaları **dosya adı sırasıyla** yapıştırıp çalıştırın.

Veritabanı değişiklikleri her zaman yeni bir migration dosyasıyla yapılır; panelden elle tablo değiştirilmez. Canlıya geçişte aynı komutlar `casper-prod` için tekrarlanır.

> Not: Migration dosyaları bu ortamda gerçek bir veritabanında çalıştırılamadı (Supabase projesi / yerel Postgres yok). İlk `db push` sırasında hata çıkarsa hata mesajını iletin.

## 3. İlk yöneticiyi atama

Uygulamadan normal şekilde kayıt olun, e-postayı doğrulayın, sonra SQL Editor içinde bir kez:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'yonetici@ornek.com');
```

Sonraki rol değişiklikleri yalnızca `admin_set_role` fonksiyonu ile (yönetim ekranından) yapılır.

## 4. Uygulamayı çalıştırma

Anahtarlar koda yazılmaz; `--dart-define` ile verilir.

```bash
copy env\dev.example.json env\dev.json
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` dosyasını kendi değerlerinizle doldurun (Supabase paneli → Project Settings → API):

```json
{
  "SUPABASE_URL": "https://<proje-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon / publishable anahtar>",
  "APP_ENV": "dev"
}
```

Canlı için `env/prod.json` oluşturup `--dart-define-from-file=env/prod.json` kullanın. Tek tek vermek de mümkündür:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Değerler verilmezse uygulama çökmeden "Yapılandırma eksik" ekranını gösterir.

**Güvenlik**

- `env/*.json` dosyaları `.gitignore` içindedir; yalnızca `*.example.json` commit edilir.
- Uygulamaya yalnızca **anon (publishable)** anahtar konur. **`service_role` anahtarı asla** uygulamaya, repoya veya `env/` dosyalarına yazılmaz.

## 5. Bu makinede derleme için gerekenler

- Windows hedefi / eklentili derleme: Windows **Geliştirici Modu** açık olmalı (`start ms-settings:developers`); Flutter eklentileri sembolik bağlantı ister.
- Android: Android Studio + Android SDK kurulu olmalı (`flutter doctor` ile kontrol edin).

## 6. Klasör yapısı

```
lib/
  core/      config (env, supabase, KVKK metni), theme (Casper renk/yazı), widgets (yükleniyor/boş/hata/çevrimdışı), utils
  features/  auth, profile, home (AuthGate + rol yönlendirme), member, trainer, admin
  demo/      eski arka uçsuz demo uygulama (kullanılmıyor; referans için saklandı)
supabase/    config.toml + migrations/
docs/        ROADMAP, BUSINESS_RULES, DB_SCHEMA, KURULUM
env/         *.example.json (gerçek değerler commit edilmez)
```
