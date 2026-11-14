# Testler

## Veritabanı testleri (pgTAP)

Konum: `supabase/tests/database/`. Her dosya tek bir transaction içinde çalışır ve `rollback` ile biter; kalıcı veri bırakmaz. Test yardımcıları (`ct` şeması: `ct.id`, `ct.make_user` …) her dosyada tekrar tanımlanır, böylece dosyalar birbirinden bağımsız çalışır.

| Dosya | Kapsam | Kurallar (BUSINESS_RULES.md) | Test sayısı |
|---|---|---|---|
| `01_packages.test.sql` | Paket atama, tek aktif paket, yenileme ve hak aktarımı, indirim | P-01..P-11, F-06, F-10, F-11, F-16 | 69 |
| `02_booking.test.sql` | Rezervasyon kontrolleri, idempotency, kontenjan, ders açma | R-01..R-11, S-01..S-04, P-04, D-06, I-05 | 59 |
| `03_cancel_freeze.test.sql` | İptal (2 saat sınırı), ders iptali, dondurma, erken bitirme, elle hak düzeltme, gelmedi | I-01..I-07, S-06, D-01..D-07, P-12 | 120 |
| `04_wallet.test.sql` | Cüzdan yükleme, ürün satışı, yetersiz bakiye, satış düzeltme | C-01..C-09 | 67 |
| `05_rls.test.sql` | Yetki ve RLS: üye, eğitmen, yönetici, pasif hesap, anon | Y-02, Y-04..Y-08, K-06, K-07, F-13 | 113 |
| `06_notifications.test.sql` | Bildirim kuyruğu: tetikleyici, tekrar etmeme, zamanlanmış görev, gönderici | B-01..B-03 | 59 |
| `07_programs_measurements_reports.test.sql` | Eğitmenin üyeleri, antrenman programları, vücut ölçümleri (RLS: üye / eğitmen / yönetici / anon), yönetici raporu sayıları | Y-04..Y-06, Y-08..Y-10, A-01..A-05, O-01..O-06, RP-01..RP-10 | 102 |
| `08_health_consent.test.sql` | Sağlık verisi açık rızası: kayıtta isteğe bağlı, rızasız ölçüm engeli, sonradan verme, geri alınca ölçümlerin silinmesi | K-09..K-12, Y-08 | 22 |

### Çalıştırma

Yerel yığın (Docker gerekir):

```
supabase start
supabase test db
```

Bağlı projede, Docker ve veritabanı şifresi olmadan (yalnızca `supabase login` yeter):

```
python supabase/tests/run_remote.py
python supabase/tests/run_remote.py supabase/tests/database/02_booking.test.sql
```

`supabase test db --remote` uzak hedefte bile pg_prove için Docker istediğinden bu betik `supabase db query --remote` kullanır. Her dosyanın sonundaki `rollback` yerine her zaman hata fırlatan bir blok koyar: hata, transaction'ı kesin olarak geri alır ve özet (`plan / run / failed`) hata mesajında döner. Betik yalnızca sayıları gösterir; bir test başarısız olursa hangisi olduğunu bulmak için ilgili dosyadaki testleri parça parça çalıştırın.

Veri bırakmaz, yine de canlıya geçtikten sonra **yalnızca dev/staging projesinde** çalıştırın.

Son çalıştırma (14.11.2026, bağlı proje, migration 20261114120000 sonrası): 8 dosya, 611 test, 0 başarısız.

`07_programs_measurements_reports.test.sql` (102 test), `20261113150000` migration'ı yüklenmeden önce migration + test tek transaction'da birleştirilip zorunlu geri alma ile denendi (13.11.2026): 102/102 başarılı, veritabanında iz kalmadı. Migration yüklendikten sonra `python supabase/tests/run_remote.py` ile 7 dosyanın tamamı yeniden çalıştırılmalı ve bu satır güncellenmelidir. Rapor testleri başka veriyle karışmaması için Ocak 2020'ye yerleştirilmiş kayıtlarla çalışır.

### Sınırlar

`now()` transaction boyunca sabit olduğundan zaman sınırları (tam 2 saat, paket bitişi) kesin ölçülür. Ancak tek transaction içinde gerçek eşzamanlılık denenemez; bunun için aşağıdaki ayrı test vardır.

## Eşzamanlılık testi

```
python supabase/tests/run_concurrency.py
```

Ayrı bağlantılardan (paralel `supabase db query --remote` süreçleri) aynı ana kilitlenmiş istekler gönderir. Test verisi commit edilir (yalnızca `concur-*@example.invalid` kullanıcıları) ve test sonunda, hata olsa bile silinir.

| Senaryo | Beklenen |
|---|---|
| A. Kapasitesi 1 olan derse 8 üye aynı anda | 1 rezervasyon, 7 × `CLASS_FULL` |
| B. Aynı üye + aynı idempotency anahtarı, 6 istek | 1 rezervasyon, 1 hak düşümü |
| C. 100 TL bakiye, 30 TL ürün, 6 farklı satış | 3 satış, 3 × `INSUFFICIENT_BALANCE`, bakiye 10 TL, hiç eksiye düşmez |
| D. Aynı anahtarla 5 satış | 1 satış, bakiye 70 TL |

Son çalıştırma (13.11.2026): 4/4 başarılı; istekler birbirinden 2–16 ms arayla ulaştı.

## Deneme verisi

Sırayla üç dosya çalıştırılır; canlıya geçmeden önce `supabase/seed/demo_cleanup.sql` ile silinir.

1. `supabase/seed/demo.sql`: hesaplar, kategori, paket tanımı, ürün, 14 günlük ders takvimi, örnek rezervasyon. Tekrar çalıştırılabilir.
2. `supabase/seed/demo_extra.sql`: her tabloda denenecek bir şey olsun diye geçmiş dersler (katıldı / gelmedi), satış ve ters kayıt, cüzdan düzeltmesi, dondurma, üye iptali, ders iptali, telafi hakkı, süresi dolmuş paket, referanslar, hesap silme talebi ve bildirimler. Bir kez çalışır.
3. `supabase/seed/demo_programs.sql` (`20261113150000` migration'ından sonra): uye1'e bir eski (pasif) ve bir aktif antrenman programı, uye4'e aktif program; uye1'e 5 haftaya yayılmış 6, uye2'ye 4 vücut ölçümü. Tekrar çalıştırılabilir. Eğitmen ekranlarında ("Üyelerim") görünen üyeler rezervasyonlara bağlıdır: Ayşe (egitmen1) → uye1, uye2, uye6; Mert (egitmen2) → uye3, uye4; Selin (egitmen3) → uye2.

`device_tokens` bilerek boştur: gerçek telefon uygulamayı açıp bildirim izni verince kendi kaydını yazar.

Durum 13.11.2026'daki yüklemeye göredir.

| Hesap (şifre `1234`) | Rol | Durum |
|---|---|---|
| `yonetici@casper.test` | yönetici | bekleyen 1 referans, 1 hesap silme talebi görür |
| `egitmen1..4@casper.test` | eğitmen | Ayşe (grup Pilates), Mert (Fonksiyonel), Selin (birebir), Kerem (uygulama akışıyla eklendi) |
| `uye1@casper.test` | üye | Pilates 8 (5 hak), 460 TL; ürün aldı, biri ters kayıtla iade; 2 onaylı referans → %10 indirim; aktif + eski antrenman programı, 6 ölçüm |
| `uye2@casper.test` | üye | Pilates 12 (10 hak), 80 TL; dün gelmedi (no-show), +1 telafi, bir rezervasyonunu iptal etti; 4 ölçüm, programı yok |
| `uye3@casper.test` | üye | Fonksiyonel 8; paketi 3.–6. gün dondurulmuş; referansı beklemede |
| `uye4@casper.test` | üye | Fonksiyonel 16; kayıtlı olduğu ders yönetici tarafından iptal edildi (hak iade); aktif antrenman programı |
| `uye5@casper.test` | üye | aktif paketi yok, süresi dolmuş eski paketi var; referansı reddedildi; hesap silme talebi bekliyor |
| `uye6@casper.test` | üye | Pilates 8, paketi 2 gün içinde bitiyor (bitiş uyarısı); 50 TL hediye, 5 TL kaldı |

Ürünler: Su, Protein Bar, Protein Shake, Elektrolit İçecek, Havlu Kiralama, Pilates Çorabı ve pasif "Yaz Kampanyası Paketi". Kategoriler: Pilates, Fonksiyonel Antrenman, Yoga.

Şifreler doğrudan veritabanına yazıldığı için uzunluk kuralına takılmaz. Uygulamadan yöneticinin hesap açarken (`admin-create-user`) en az 4, üyenin kendi kaydında en az 6 karakter gerekir.

## Uygulama testleri (Flutter)

```
flutter test
```

13.11.2026'da eklenenler (sahte depo + `ProviderScope` override kalıbı, bkz. `test/packages/fake_repo.dart`): `test/workouts/` (program modeli, üye ve eğitmen ekranları, program düzenleyici), `test/measurements/` (ilerleme hesabı, doğrulama, ölçüm ekranı ve formu, eğilim çizgisi), `test/reports/` (rapor modeli, tarih aralıkları, rapor ekranı), `test/trainer/` (eğitmenin üyeleri listesi ve arama). Son çalıştırma (13.11.2026): 88 test, 0 başarısız.

## Elle doğrulanacaklar (pilot öncesi)

- Eğitmen hesabıyla: Üyelerim → üye → program hazırla / ölçüm gir; başka eğitmenin üyesinin listede olmadığı
- Üye hesabıyla: Antrenman programım, Ölçümlerim ve ilerleme (kilo eğilim çizgisi, açık ve koyu tema)
- Yönetici hesabıyla: Raporlar (bu ay, geçen ay, özel aralık)

- Gerçek iPhone ve Android cihazda giriş, takvim, bildirim izni ve bildirim alma
- Bağlantı koptuktan sonra tekrarlanan rezervasyon isteğinin çift kayıt oluşturmaması
- Pilot: 3 eğitmen ve küçük bir üye grubu

`20261114120000` (sağlık rızası) migration'ı yüklenmeden önce 07 ve 08, migration ile tek transaction'da birleştirilip zorunlu geri alma ile denendi (14.11.2026): 102/102 ve 22/22 başarılı. 07'deki test kullanıcıları artık kayıtta sağlık rızası verir.
