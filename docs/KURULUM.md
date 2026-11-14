# Kurulum ve Çalıştırma

## 1. Supabase projeleri (geliştirme ve canlı ayrı)

1. https://supabase.com üzerinde iki proje açın: `casper-dev` ve (yayına yakın) `casper-prod`.
2. Her projede **Authentication → URL Configuration**:
   - Site URL: `caspertraining://auth-callback`
   - Redirect URLs: `caspertraining://auth-callback`
3. **Authentication → Sign In / Providers → Email**: "Confirm email" açık olsun; en az şifre uzunluğu 6 (Supabase'in izin verdiği en kısa değer).

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
docs/        ROADMAP, BUSINESS_RULES, DB_SCHEMA, KURULUM, TESTING, YONETICI_KILAVUZU
env/         *.example.json (gerçek değerler commit edilmez)
```

## 7. Canlı ortam (`casper-prod`) kontrol listesi

Canlı proje, geliştirme projesinden ayrıdır; deneme verisi canlıya **asla** yüklenmez.

1. **Proje:** Supabase'de `casper-prod` projesini açın (bölge: Avrupa, ör. Frankfurt). Bölüm 1'deki URL ve e-posta ayarlarını aynen yapın.
2. **Şema:** `supabase link --project-ref <PROD_REF>` → `supabase db push`. `supabase/seed/` altındaki `demo*.sql` dosyaları canlıda **çalıştırılmaz**.
3. **Edge Functions:** `supabase functions deploy admin-create-user` ve `supabase functions deploy send-notifications`.
4. **Gizli değerler:** `supabase secrets set NOTIFY_CRON_SECRET=<uzun rastgele değer>`. Telefon bildirimi kurulunca ayrıca `FCM_SERVICE_ACCOUNT` (Firebase servis hesabı JSON'u, tek satır).
5. **E-posta (SMTP):** Supabase'in yerleşik e-posta servisi saatte birkaç e-postayla sınırlıdır; canlıda **Authentication → Emails → SMTP Settings** ile kendi SMTP sağlayıcınızı (ör. Resend, Brevo, Google Workspace) girin. Gönderen adı: "Casper Training Studio". Türkçe şablonlar hazır (`supabase/templates/`); SMTP girildikten sonra `supabase/config.toml` içindeki şablon satırlarının yorumu kaldırılıp `supabase config push` çalıştırılır. **SMTP olmadan Supabase yalnızca proje ekibindeki adreslere e-posta gönderir ve şablon değiştirmeye izin vermez; gerçek üyeler doğrulama e-postası alamaz.** En kolay yol: caspersporkulubu@gmail.com için Google hesabında 2 adımlı doğrulama → Uygulama şifresi; panelde Host `smtp.gmail.com`, Port `465`, kullanıcı adı Gmail adresi, şifre uygulama şifresi.
6. **Yedekleme:** Ücretsiz planda otomatik yedek yoktur. Canlıda **Pro plan** (günlük yedek) önerilir. Ek olarak haftalık el ile yedek: `supabase db dump --linked -f yedek_YYYYAAGG.sql` (dosya güvenli bir yerde, repoda değil, saklanır).
7. **İlk yönetici:** Bölüm 3'teki adım canlı projede bir kez yapılır.
8. **Uygulama:** `env/prod.json` (`env/prod.example.json` kopyası) canlı URL ve anon anahtarla doldurulur; mağaza paketi `--dart-define-from-file=env/prod.json` ile derlenir.
9. **Hata takibi:** Henüz kurulu değil; pilottan sonra karar verilecek (ör. Sentry ücretsiz plan).

## 8. Android yayın imzası

Mağazaya yüklenen her sürüm **aynı anahtarla** imzalanmalıdır. Anahtar kaybolursa uygulama güncellenemez; dosyayı ve şifreleri repoda değil, güvenli iki ayrı yerde saklayın.

1. Anahtarı bir kez oluşturun (repo dışında bir klasörde):

   ```bash
   keytool -genkey -v -keystore C:\anahtarlar\casper-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   (`keytool`, Android Studio ile gelen JDK içindedir: `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.)

2. `android/key.properties` dosyasını oluşturun (git'e girmez):

   ```properties
   storePassword=<anahtar deposu şifresi>
   keyPassword=<anahtar şifresi>
   keyAlias=upload
   storeFile=C:\anahtarlar\casper-upload.jks
   ```

3. Mağaza paketi: `flutter build appbundle --release --dart-define-from-file=env/prod.json` → `build/app/outputs/bundle/release/app-release.aab`.

`key.properties` yoksa release derlemesi debug anahtarıyla imzalanır (cihazda denemek için yeterli, mağazaya yüklenemez). Google Play'de **Play App Signing** açık bırakılır; yukarıdaki anahtar "yükleme anahtarı" olur.

Sürüm numarası `pubspec.yaml` içindeki `version: 1.0.0+1` satırından gelir; her mağaza yüklemesinde `+` sonrasındaki sayı artırılır.
