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

Son çalıştırma (13.11.2026, bağlı proje): 6 dosya, 487 test, 0 başarısız.

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

`supabase/seed/demo.sql` uygulamayı elle denemek için hesap, kategori, paket, ürün, 14 günlük ders takvimi ve örnek rezervasyon ekler. Tekrar çalıştırılabilir. Canlıya geçmeden önce `supabase/seed/demo_cleanup.sql` ile silinir.

| Hesap (şifre `1234`) | Rol | Durum |
|---|---|---|
| `yonetici@casper.test` | yönetici | |
| `egitmen1..3@casper.test` | eğitmen | Ayşe (grup Pilates), Mert (Fonksiyonel), Selin (birebir) |
| `uye1@casper.test` | üye | Pilates 8, cüzdan 500 TL, yarın 10:00 kayıtlı |
| `uye2@casper.test` | üye | Pilates 12, cüzdan 200 TL, yarın 10:00 kayıtlı |
| `uye3@casper.test` | üye | Fonksiyonel 8 |
| `uye4@casper.test` | üye | Fonksiyonel 16, yarın 18:00 kayıtlı |
| `uye5@casper.test` | üye | paketi yok |
| `uye6@casper.test` | üye | Pilates 8, cüzdan 0 TL |

Şifreler doğrudan veritabanına yazıldığı için 6 karakter kuralına takılmaz; uygulamadan şifre değiştirirken kural yine geçerlidir.

## Uygulama testleri (Flutter)

```
flutter test
```

## Elle doğrulanacaklar (pilot öncesi)

- Gerçek iPhone ve Android cihazda giriş, takvim, bildirim izni ve bildirim alma
- Bağlantı koptuktan sonra tekrarlanan rezervasyon isteğinin çift kayıt oluşturmaması
- Pilot: 3 eğitmen ve küçük bir üye grubu
