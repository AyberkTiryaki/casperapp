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

`now()` transaction boyunca sabit olduğundan zaman sınırları (tam 2 saat, paket bitişi) kesin ölçülür. Ancak tek transaction içinde gerçek eşzamanlılık denenemez. Son kontenjana aynı anda rezervasyon ve eşzamanlı cüzdan harcaması için pgTAP testleri kilitleme ve idempotency davranışını sırayla doğrular; gerçek yarış koşulu için iki ayrı bağlantıdan aynı anda istek atan ayrı bir yük testi gerekir (ROADMAP §13).

## Uygulama testleri (Flutter)

```
flutter test
```

## Elle doğrulanacaklar (pilot öncesi)

- Gerçek iPhone ve Android cihazda giriş, takvim, bildirim izni ve bildirim alma
- Bağlantı koptuktan sonra tekrarlanan rezervasyon isteğinin çift kayıt oluşturmaması
- Pilot: 3 eğitmen ve küçük bir üye grubu
