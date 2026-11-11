# İş Kuralları

Kaynak: `docs/ROADMAP.md`. Bu belge kuralları test edilebilir biçimde kesinleştirir. Her kuralın bir kimliği vardır; testler ve hata kodları bu kimliklere bağlanır. Kuralların sunucudaki karşılığı `supabase/migrations/` içindeki RPC fonksiyonlarıdır (özet: `docs/DB_SCHEMA.md`).

**Genel ilkeler**

- Tüm kurallar sunucuda (PostgreSQL fonksiyonları, tek transaction) uygulanır. Ekrandaki kontroller yalnızca kullanıcı deneyimi içindir.
- Zamanlar `timestamptz` (UTC) saklanır. Gün bazlı kurallar (dondurma) `Europe/Istanbul` gününe göre hesaplanır.
- "Şimdi" = isteğin sunucuya ulaştığı an (transaction başlangıcı).
- Hak ve cüzdan hareketleri silinmez ve değiştirilmez; düzeltme yeni hareketle yapılır.

## Onaylanan kararlar

Yol haritasındaki açık kararlar 10 Kasım 2026'da stüdyo tarafından aşağıdaki gibi onaylandı. Değişirse ilgili kural ve fonksiyon güncellenir.

| # | Karar | **ONAYLANDI** | Kural | Uygulandığı yer |
|---|---|---|---|---|
| a | Paket geçerliliği neyi kapsar? | Rezervasyon, paket hem **rezervasyon anında** hem **ders tarihinde** geçerliyse yapılabilir. | R-04, R-05 | `book_class` |
| b | Dondurma süresi bitişe eklenir mi? | **Evet.** Dondurulan gün sayısı paketin bitiş tarihine eklenir. | D-04 | `freeze_package` |
| c | Yenilemede/aktarımda rezervasyonlar | Gelecek rezervasyon yalnızca yeni paket **aynı kategorideyse, hakkı kaldıysa ve ders tarihinde geçerliyse** aktarılır. Aksi halde iptal edilir ve hak **eski paketin** hareketlerine iade edilir. | P-08, P-09 | `assign_package` |

Yol haritasında açıkça yazmayan ek kararlar 11. bölümdedir (10 Kasım 2026'da onaylandı). Adım 3 ek kararları 12. bölümdedir (onaylandı). Referans sistemi kuralları 13. bölümde, onaylanan referans kararları 14. bölümde, henüz onaylanmamış yeni varsayımlar 15. bölümdedir.

## 1. Kayıt, profil, KVKK (K)

| Kimlik | Kural |
|---|---|
| K-01 | Kayıt e-posta + şifre ile yapılır; şifre en az 8 karakterdir. E-posta doğrulanmadan oturum açılamaz. |
| K-02 | Kayıtta ad soyad, doğum tarihi, boy (cm), kilo (kg) alınır. **Kronik rahatsızlık / sağlık alanı yoktur.** |
| K-03 | Doğum tarihi geçmişte olmalıdır. Sunucu boy için 50–260 cm, kilo için 20–400 kg kabul eder (uygulama formu 100–250 cm ve 30–300 kg ister). Aralık dışı değer sunucuda boş kaydedilir. |
| K-04 | Kayıt, KVKK onay kutusu işaretlenmeden tamamlanamaz. Onay, **metin sürümü + onay zamanı** ile `consents` tablosuna yazılır. Metin değişince yeni sürüm ayrıca onaylanır (`accept_kvkk`). |
| K-05 | Profilde yalnızca **güncel** kilo tutulur; kilo geçmişi tutulmaz. |
| K-06 | Her yeni hesabın rolü **üye**dir. Kayıt verisindeki hiçbir alan rolü değiştiremez. |
| K-07 | Üye kendi profilinde yalnızca ad soyad, doğum tarihi, boy ve kiloyu değiştirebilir. |
| K-08 | Üye hesap silme talebi oluşturabilir; aynı anda tek bekleyen talep olur. Talebi yönetici sonuçlandırır (süreç adım 8). |

## 2. Roller ve yetki (Y)

| Kimlik | Kural |
|---|---|
| Y-01 | Üç rol vardır: üye (`member`), eğitmen (`trainer`), yönetici (`admin`). Rol yalnızca sunucudaki `profiles.role` alanından okunur. |
| Y-02 | Rolü yalnızca yönetici, `admin_set_role` ile değiştirir. Üye/eğitmen kendi rolünü değiştiremez. Yönetici kendi rolünü düşüremez ve kendini pasifleştiremez. |
| Y-03 | İlk yönetici bir kez Supabase SQL Editor üzerinden atanır (bkz. `docs/KURULUM.md`). |
| Y-04 | Üye yalnızca kendi profilini, paketlerini, hak hareketlerini, rezervasyonlarını, cüzdanını ve satışlarını görür. Başka üyenin hiçbir verisini göremez. |
| Y-05 | Eğitmen: takvimi, kendi derslerinin katılımcılarını (yalnızca ad), üye aramayı (yalnızca ad) ve kendi yaptığı satışları görür. Üyelerin boy/kilo/doğum tarihi, paket ve cüzdan bilgilerini göremez; yönetici işlemlerini çağıramaz. |
| Y-06 | Yönetici tüm verileri görür; paket, dondurma, cüzdan, rol ve tanım yönetimi yapar. |
| Y-07 | Pasif hesap (`is_active = false`) hiçbir role sahip sayılmaz; işlem yapamaz. |
| Y-08 | Giriş yapmamış istemci (anon) hiçbir tabloya ve fonksiyona erişemez. `service_role` anahtarı mobil uygulamada bulunmaz. |
| Y-09 | Yöneticinin yaptığı kritik işlemler (rol, paket atama, dondurma, iptal, cüzdan) `audit_log` tablosuna yazılır. |

## 3. Paketler (P)

| Kimlik | Kural |
|---|---|
| P-01 | Paket tanımı: kategori, ders sayısı, geçerlilik günü, fiyat. Ders sayısı 8, 12, 16 veya 20 olur. |
| P-02 | Geçerlilik: 8 ve 12 derslik paket **30 gün**, 16 ve 20 derslik paket **40 gün**. Süre aktivasyon anından başlar; bitiş = aktivasyon + gün sayısı (bitiş anı dahil değildir). |
| P-03 | Paketi yalnızca yönetici atar; paket atandığı anda aktifleşir. |
| P-04 | Paket yalnızca kendi kategorisindeki derslerde kullanılır. |
| P-05 | Bir üyenin aynı kategoride en fazla **bir** aktif paketi olur. Farklı kategorilerde aynı anda aktif paket olabilir. |
| P-06 | Atama anındaki fiyat pakete kopyalanır (`price_paid`). Sonradan yapılan fiyat değişikliği atanmış paketleri etkilemez. |
| P-07 | Süresi dolmamış aktif paket varken aynı kategoride yeni paket atanamaz (`ACTIVE_PACKAGE_EXISTS`); yönetici **yenileme** seçerse (`p_replace_existing`) eski paket erken bitirilir (`terminated`) ve yenisi aktif olur. Süresi dolmuş eski paket otomatik `expired` yapılır. |
| P-08 | **(Varsayılan c)** Yenilemede eski paketin gelecek rezervasyonları ders tarihi sırasıyla işlenir: yeni pakette hak varsa **ve** ders, yeni paketin bitişinden önceyse rezervasyon yeni pakete aktarılır (eski pakete +1 `transfer_out`, yeni paketten −1 `transfer_in`). |
| P-09 | **(Varsayılan c)** Aktarılamayan rezervasyon iptal edilir ve hak eski paketin hareketlerine iade edilir. Eski paket kapalı olduğu için bu hak kullanılamaz; kayıt amaçlıdır. |
| P-10 | Eski paketin kalan hakları yenilemeyle biter (kapalı paketle rezervasyon yapılamaz). |
| P-11 | Paket atama tekrarlanan istekte (aynı idempotency anahtarı) ikinci paket yaratmaz. |
| P-12 | Yönetici bir paketin hakkını elle ±1..100 düzeltebilir (`admin_adjust_credits`). Not zorunludur, hak 0'ın altına düşemez; `credit_ledger`'a `adjustment` kaydı ve audit kaydı yazılır. Paket durumu denetlenmez. | `INVALID_CREDIT_DELTA`, `NOTE_REQUIRED`, `NO_CREDITS`, `PACKAGE_NOT_FOUND` |

## 4. Dersler (S)

| Kimlik | Kural |
|---|---|
| S-01 | Eğitmen yalnızca kendi adına ders açar; yönetici herhangi bir eğitmen adına açabilir. |
| S-02 | Bireysel ders kapasitesi **1**, grup dersi kapasitesi **6** olur; başka değer olamaz. |
| S-03 | Ders gelecekte olmalıdır; süre 15–240 dakikadır (varsayılan 60 dk). |
| S-04 | Aynı eğitmenin zaman olarak çakışan iki dersi olamaz (`TRAINER_BUSY`). |
| S-05 | Giriş yapmış herkes takvimi, kategoriyi, eğitmeni ve kalan kontenjanı (`capacity − booked_count`) görür. |
| S-06 | Dersi eğitmeni (başlamadan önce, haklar her zaman iade edilerek) veya yönetici (her zaman, iadeyi seçerek) iptal eder; tüm rezervasyonlar iptal edilir. |

## 5. Rezervasyon (R)

Tüm kontroller ve hak düşümü `book_class` içinde tek transaction olarak yapılır.

| Kimlik | Kural | Hata kodu |
|---|---|---|
| R-01 | Yalnızca aktif **üye** rezervasyon yapar (yönetici, üye adına yapabilir). | `MEMBER_NOT_ELIGIBLE` |
| R-02 | Ders planlanmış olmalı ve başlamamış olmalıdır. | `CLASS_CANCELLED`, `CLASS_ALREADY_STARTED` |
| R-03 | Üyenin dersin **kategorisinde** aktif paketi olmalıdır. | `NO_ACTIVE_PACKAGE` |
| R-04 | **(Varsayılan a)** Paket rezervasyon anında geçerli olmalıdır: `activated_at ≤ şimdi < ends_at`. | `PACKAGE_EXPIRED` |
| R-05 | **(Varsayılan a)** Ders başlangıcı paketin bitişinden önce olmalıdır: `starts_at < ends_at`. | `CLASS_AFTER_PACKAGE_END` |
| R-06 | Rezervasyon anı veya ders başlangıcı paketin bir dondurma aralığına denk geliyorsa rezervasyon yapılamaz. | `PACKAGE_FROZEN` |
| R-07 | Pakette en az 1 hak kalmış olmalıdır; rezervasyon 1 hak düşer. Hak asla eksiye düşmez. | `NO_CREDITS` |
| R-08 | Aynı üye aynı derse ikinci (iptal edilmemiş) rezervasyon yapamaz. İptalden sonra yeniden rezervasyon yapabilir. | `ALREADY_BOOKED` |
| R-09 | Kontenjan dolmuşsa rezervasyon yapılamaz. Eşzamanlı isteklerde son kontenjan **tek** üyeye verilir; diğerleri `CLASS_FULL` alır. | `CLASS_FULL` |
| R-10 | Her istek bir idempotency anahtarı (UUID) taşır. Aynı anahtarla tekrarlanan istek ikinci rezervasyon veya ikinci düşüm yaratmaz; ilk sonucu döndürür. Aynı anahtar başka ders için kullanılamaz. | `IDEMPOTENCY_KEY_REUSED` |
| R-11 | Her rezervasyon için en fazla bir `booking` (−1) ve en fazla bir `refund` (+1) hak hareketi olur. | — |
| R-12 | Üye aktif paketlerini, kalan haklarını, gelecek ve geçmiş rezervasyonlarını görür. | — |

## 6. İptal (I)

| Kimlik | Kural | Hata kodu |
|---|---|---|
| I-01 | Üye yalnızca kendi rezervasyonunu, derse **en az 2 saat** varken iptal edebilir: `şimdi ≤ starts_at − 2 saat`. **Tam 2 saat kala iptal edilebilir**; 2 saatten 1 saniye az kaldıysa edilemez. | `CANCEL_WINDOW_CLOSED` |
| I-02 | Üyenin zamanında iptalinde hak her zaman iade edilir. | — |
| I-03 | Yönetici her zaman iptal edebilir ve hak iadesini **açıkça seçmek zorundadır** (evet/hayır). | `REFUND_CHOICE_REQUIRED` |
| I-04 | Tekrarlanan iptal isteği ikinci iade yaratmaz; mevcut iptal kaydını döndürür. | — |
| I-05 | İptal, dersin dolu kontenjanını 1 azaltır (yer açılır). | — |
| I-06 | Üye derse gelmezse otomatik ek düşüm yapılmaz; düşülmüş hak kalır. Gerekirse yönetici manuel hak düzeltmesi girer (`admin_adjust_credits`, P-12). Yönetici ders başladıktan sonra rezervasyonu kayıt amaçlı "gelmedi" işaretleyebilir ve geri alabilir (`admin_set_no_show`; hak değişmez). | `CLASS_NOT_STARTED`, `RESERVATION_NOT_ACTIVE` |
| I-07 | Üye başkasının rezervasyonunu iptal etmeye çalışırsa "bulunamadı" yanıtı alır (varlığı sızdırılmaz). | `RESERVATION_NOT_FOUND` |

## 7. Dondurma (D)

| Kimlik | Kural | Hata kodu |
|---|---|---|
| D-01 | Paketi yalnızca yönetici dondurur. Aralık başlangıç ve bitiş **günü** ile verilir (her iki gün dahil, İstanbul saati). | `FORBIDDEN` |
| D-02 | Başlangıç bugünden önce olamaz; bitiş başlangıçtan önce olamaz; aralık paket bitişinden önce başlamalıdır; paket aktif ve süresi dolmamış olmalıdır. | `FREEZE_IN_PAST`, `INVALID_FREEZE_RANGE`, `FREEZE_OUTSIDE_PACKAGE`, `PACKAGE_NOT_ACTIVE` |
| D-03 | Aynı paketin dondurma aralıkları çakışamaz. | `FREEZE_OVERLAP` |
| D-04 | **(Varsayılan b)** Dondurulan gün sayısı paketin bitiş tarihine eklenir. | — |
| D-05 | Dondurma aralığına denk gelen (ve henüz başlamamış) rezervasyonlar iptal edilir, hakları iade edilir. Aralık dışındaki rezervasyonlar korunur. | — |
| D-06 | Dondurma süresince ve dondurma aralığındaki derslere rezervasyon yapılamaz (R-06). | `PACKAGE_FROZEN` |
| D-07 | **Erken bitirme** (`admin_end_freeze`, yalnızca yönetici): `p_last_day` boşsa başlamamış dondurma tamamen kaldırılır, başlamışsa dün biter. Doluysa yeni son gün (dahil) bugünden önceki günden, dondurma ilk gününden bir gün öncesinden küçük olamaz ve mevcut son günden önce olmalıdır (uzatma yeni dondurmadır). Kaldırılan gün sayısı paket bitişinden düşülür (D-04'ün tersi); dondurma sırasında iptal edilen rezervasyonlar geri gelmez. Paket aktif olmalıdır. | `FREEZE_NOT_FOUND`, `FREEZE_ALREADY_ENDED`, `INVALID_FREEZE_RANGE`, `PACKAGE_NOT_ACTIVE` |

## 8. Cüzdan ve ürün satışı (C)

| Kimlik | Kural | Hata kodu |
|---|---|---|
| C-01 | Bakiyeyi yalnızca yönetici yükler. Tutar pozitif ve en fazla 2 ondalıklıdır. **Ödeme yöntemi kaydı tutulmaz.** | `INVALID_AMOUNT` |
| C-02 | Üye kendi bakiyesini ve hareketlerini görür. | — |
| C-03 | Satışı eğitmen veya yönetici yapar: üye + ürün + adet (1–100). | `FORBIDDEN`, `INVALID_QUANTITY` |
| C-04 | Birim fiyat sunucuda, **işlem anındaki** ürün fiyatından alınır ve satışa kopyalanır; istemciden fiyat kabul edilmez. | — |
| C-05 | Bakiye yetersizse satış yapılmaz. Bakiye hiçbir koşulda eksiye düşmez; eşzamanlı harcamalarda da geçerlidir. | `INSUFFICIENT_BALANCE` |
| C-06 | Aynı idempotency anahtarıyla tekrarlanan satış/yükleme ikinci kez işlenmez. | `IDEMPOTENCY_KEY_REUSED` |
| C-07 | Her bakiye değişiminin bir hareket kaydı vardır (`topup`, `purchase`, `reversal`, `adjustment`) ve hareket, işlem sonrası bakiyeyi içerir. | — |
| C-08 | Hatalı işlem silinmez. Yönetici **ters kayıt** (bir hareket en fazla bir kez; ters kaydın tersi alınamaz) veya açıklamalı **düzeltme** hareketi girer. | `ALREADY_REVERSED`, `CANNOT_REVERSE_REVERSAL`, `NOTE_REQUIRED` |
| C-09 | Ters kayıt bakiyeyi eksiye düşürecekse yapılmaz. | `INSUFFICIENT_BALANCE` |
| C-10 | Cüzdan paketten bağımsızdır: üyelik/paket bitse de bakiye kullanılabilir. | — |
| C-11 | Kapsam dışı: stok takibi, QR, üye onayı. | — |

## 9. Bildirimler (B) — adım 7

| Kimlik | Kural |
|---|---|
| B-01 | Bildirim türleri: rezervasyon onayı, ders iptali, ders hatırlatması, paket bitiş uyarısı. |
| B-02 | Her bildirimin benzersiz bir `dedupe_key` değeri vardır; aynı bildirim iki kez gönderilmez. |
| B-03 | Gönderim sonucu (`sent` / `failed` + hata) saklanır. Cihaz bağlantısını yalnızca sahibi yönetir. |

## 10. Test senaryoları (yol haritası §13 ile eşleşme)

| Senaryo | Beklenen | Kurallar |
|---|---|---|
| Kapasitesi 1 kalan derse 2 üye aynı anda rezervasyon yapar | Biri başarılı, diğeri `CLASS_FULL`; `booked_count = capacity`; toplam 1 hak düşer | R-09 |
| Aynı istek bağlantı kopunca tekrar gönderilir (aynı anahtar) | Tek rezervasyon, tek `booking` hareketi, aynı yanıt | R-10, R-11 |
| Derse tam 2 saat kala iptal | Başarılı, +1 iade | I-01, I-02 |
| Derse 1 sa 59 dk 59 sn kala iptal | `CANCEL_WINDOW_CLOSED`, hak değişmez | I-01 |
| Süresi dolmuş paketle rezervasyon | `PACKAGE_EXPIRED` | R-04 |
| Paket bitişinden sonraki derse rezervasyon | `CLASS_AFTER_PACKAGE_END` | R-05 |
| Hakkı bitmiş paketle rezervasyon | `NO_CREDITS` | R-07 |
| Yanlış kategorideki derse rezervasyon | `NO_ACTIVE_PACKAGE` | P-04, R-03 |
| Dondurma aralığında 2, dışında 1 gelecek rezervasyon varken dondurma | 2 iptal + 2 iade, 1 korunur, bitiş gün sayısı kadar uzar | D-04, D-05 |
| 3 gelecek rezervasyonu olan üyenin paketi yenilenir (yeni pakette hak var, dersler geçerlilik içinde) | 3 rezervasyon da yeni pakete aktarılır; yeni paket hakkı 3 azalır | P-08 |
| Yenilemede bir ders yeni paket bitişinden sonra | O rezervasyon iptal, hak eski pakete iade | P-09 |
| Aynı üyeye eşzamanlı 2 satış, bakiye yalnızca birine yeter | Biri başarılı, diğeri `INSUFFICIENT_BALANCE`; bakiye ≥ 0 | C-05 |
| Aynı satış isteği iki kez gönderilir | Tek satış, tek `purchase` hareketi | C-06 |
| Hatalı satış ters kayıtla düzeltilir | Bakiye geri gelir; satış `reversed_at` ile işaretlenir; ikinci ters kayıt `ALREADY_REVERSED` | C-08 |
| Üye başka üyenin profilini/paketini/cüzdanını sorgular | Boş sonuç (RLS) | Y-04 |
| Eğitmen `assign_package` / `admin_wallet_topup` çağırır | `FORBIDDEN` | Y-05 |
| Üye `profiles.role` alanını güncellemeye çalışır | Yetki hatası | Y-02, K-07 |

## 11. Onaylanan ek kararlar

Yol haritasında açıkça yazmayan aşağıdaki kararlar 10 Kasım 2026'da stüdyo tarafından onaylandı.

1. Paket atandığı anda aktifleşir; ileri tarihli aktivasyon yoktur (P-03).
2. Eğitmen kendi dersini (başlamadan önce) iptal edebilir; haklar her zaman iade edilir (S-06).
3. Aynı eğitmenin çakışan dersi açılamaz; ders süresi 15–240 dk (S-03, S-04).
4. Dondurma süresince, dondurma sonrası tarihli derslere de rezervasyon yapılamaz (R-06).
5. Yönetici ve eğitmen hesapları rezervasyon yapamaz; yalnızca üye rolü yapar (R-01).
6. Süresi dolan paketin durumu şimdilik yeni atama sırasında `expired` yapılır; geçerlilik her işlemde `ends_at` üzerinden anlık kontrol edilir. **Uygulandı (adım 5):** `expire-packages` zamanlanmış görevi her 15 dakikada `private.expire_packages()` çalıştırır; yalnızca durumu günceller, kurallar yine `ends_at` ile anlık denetlenir.
7. Dondurmayı erken bitirme (`admin_end_freeze`, D-07), manuel hak düzeltme (`admin_adjust_credits`, P-12) ve gelmedi işaretleme (`admin_set_no_show`) **uygulandı (adım 5).**
8. Tam 2 saat kala iptal serbesttir (I-01); yönetici iptalinde iade seçimi zorunludur (I-03).
9. Kayıt verisinde KVKK onayı yoksa (ör. panelden açılan hesap) profil yine oluşur, onay kaydı yazılmaz.

**Yapılacak iş (karar değil):** Uygulamadaki KVKK aydınlatma metni taslaktır (`lib/core/config/legal.dart`); yayından önce hukuki metinle değiştirilmeli ve sürüm numarası güncellenmelidir.

## 12. Onaylanan ek kararlar — adım 3: paket yönetimi

Aşağıdaki kararlar 10 Kasım 2026'da stüdyo tarafından onaylandı.

1. Kategori ve paket tanımı **silinmez**, pasife alınır (geçmiş atamalar tanıma bağlı kalır). Pasif tanım yeni atamada seçilemez.
2. Paket tanımındaki değişiklikler (fiyat, ad, ders sayısı) yalnızca sonraki atamaları etkiler; atanmış paketin fiyatı, toplam hakkı ve bitiş tarihi atama anındaki değerlerle saklanır (P-06 kapsamının genişletilmesi).
3. Üye, pasife alınmış olsa bile kendi paketinin bağlı olduğu paket tanımının ve kategorinin adını görebilir.
4. Erken sonlandırma tek başına yapılamaz; yalnızca aynı kategoride yeni paket atanırken ("yenile") yapılır (P-07).
5. Yönetici, süresi dolmamış aktif paketi olan üyeye aynı kategoride paket atamak istediğinde uygulama önce uyarır; yönetici onaylarsa yenileme yapılır.
6. Ekranda, durumu `active` olup bitiş tarihi geçmiş paket "Süresi doldu" olarak gösterilir (yalnızca gösterim; kural sunucudadır).
7. Dondurma tek seferde en fazla 365 gün olabilir; aynı paket birden çok kez (çakışmayan aralıklarla) dondurulabilir.

## 13. Referans sistemi (F)

Kaynak: `docs/ROADMAP.md` §15 (10 Kasım 2026, stüdyo onaylı). Sunucu karşılığı: `supabase/migrations/20261111100000_referrals.sql`.

| Kimlik | Kural | Hata kodu |
|---|---|---|
| F-01 | Her kullanıcının benzersiz bir referans kodu vardır; kayıt anında sunucuda otomatik üretilir. Kod 7 karakterdir, yalnızca `ABCDEFGHJKMNPQRSTUVWXYZ23456789` karakterlerini içerir (karışan I, L, O, 0, 1 yoktur). Kullanıcı kodunu değiştiremez. | — |
| F-02 | Kod üretimi çakışmaya dayanıklıdır: benzersizlik kısıtı ihlalinde yeni kodla yeniden denenir (en fazla 10 deneme). | — |
| F-03 | Kayıt formunda referans kodu **isteğe bağlıdır**. Geçerli bir kod girilirse `pending` (beklemede) bir referans oluşur. | — |
| F-04 | Kendi koduyla referans oluşmaz. Bir kişi yalnızca **bir kez** referans alabilir (getirilen başına tek kayıt). | — |
| F-05 | Her yeni referans yönetici paneline beklemede düşer; yönetici **onaylar** veya **reddeder**. Yalnızca yönetici karar verebilir. | `FORBIDDEN`, `REFERRAL_NOT_FOUND`, `DECISION_REQUIRED` |
| F-06 | Bir referans **sayılır** ancak ve ancak: durumu `approved` **ve** getirilen kişinin şu an kullanılabilir bir paketi varsa (durumu aktif, `activated_at ≤ şimdi < ends_at`, şu an bir dondurma aralığında değil). Herhangi bir kategorideki tek paket yeterlidir. | — |
| F-07 | Sayım anlık hesaplanır: getirilenin paketi bitince/dondurulunca referans sayımdan düşer; yeniden paket alınca veya dondurma bitince geri gelir. | — |
| F-08 | İndirim oranı = sayılan referans sayısı × %5, **en fazla %50**. | — |
| F-09 | İndirim uygulamada **otomatik düşülmez**. Ödemeyi yönetici fiziksel olarak alır; paket atarken uygulanan oranı (0 olabilir) kaydeder. | — |
| F-10 | Paket atamasında liste fiyatı (`list_price`), uygulanan oran (`discount_percent`) ve indirimli fiyat (`price_paid = liste × (100 − oran) / 100`, 2 ondalık) saklanır. | — |
| F-11 | Sunucu, kaydedilen oranın 0–50 aralığında ve atanan üyenin **o anki** hak ettiği orandan büyük olmamasını zorunlu kılar. Yönetici hak edilenden az verebilir. | `INVALID_DISCOUNT`, `DISCOUNT_EXCEEDS_ENTITLEMENT` |
| F-12 | Tekrarlanan paket atama isteği (aynı idempotency anahtarı), indirim hakkı o arada değişmiş olsa bile ilk sonucu döndürür. | — |
| F-13 | Üye kendi kodunu, sayılan referans sayısını, güncel indirim oranını ve bekleyen referans sayısını görür. Getirdiği kişiler için yalnızca **"Ad S."** (ad + soyadın baş harfi), durum ve şu an sayılıp sayılmadığı görünür; başka hiçbir kişisel veri görünmez. | — |
| F-14 | Yönetici paneli: tüm referanslar (getiren, getirilen, tarih, durum, getirilenin aktif paketi var mı), duruma göre filtre, bekleyenler için onay/ret, getirenin güncel indirim oranı. | — |
| F-15 | Referans kararları `audit_log` tablosuna yazılır. | — |
| F-16 | Yönetici bir kullanıcıya **elle referans ekleyebilir**: getireni ve getirileni seçer. Getirilenin zaten bir referansı varsa eklenemez; kişi kendi kendine referans olamaz. Kayıt doğrudan **onaylı** oluşur ve denetim kaydına yazılır (`admin_create_referral`). | `REFERRAL_ALREADY_EXISTS`, `SELF_REFERRAL`, `USER_NOT_FOUND`, `FORBIDDEN` |

**Test senaryoları**

| Senaryo | Beklenen | Kurallar |
|---|---|---|
| Geçerli kodla kayıt | `pending` referans oluşur; getirenin oranı değişmez | F-03, F-06 |
| Geçersiz / kendi koduyla kayıt | Kayıt tamamlanır, referans oluşmaz, kullanıcıya uyarı gösterilir | F-04, §14-1 |
| Onaylı referans, getirilenin paketi yok | Sayılmaz; oran %0 | F-06 |
| Onaylı 3 referans, üçünün de aktif paketi var | Oran %15 | F-08 |
| Onaylı 12 referans, hepsinin aktif paketi var | Oran %50 (tavan) | F-08 |
| Getirilenin paketi dondurulur / süresi biter | O referans sayımdan düşer; oran %5 azalır | F-07 |
| Hak %10 iken yönetici %15 ile paket atar | `DISCOUNT_EXCEEDS_ENTITLEMENT`; paket oluşmaz | F-11 |
| Hak %10 iken yönetici %0 veya %5 ile atar | Başarılı; `discount_percent` ve `price_paid` kaydedilir | F-09, F-10 |
| Üye `referrals` tablosunu doğrudan sorgular | Boş sonuç (RLS) | F-13 |
| Eğitmen/üye `admin_decide_referral` çağırır | `FORBIDDEN` | F-05 |

## 14. Onaylanan ek kararlar — adım 3b: referans sistemi

Aşağıdaki kararlar stüdyo tarafından onaylandı. 2. madde sonradan F-16 ile genişletildi (yönetici elle referans ekleyebilir).

1. **Geçersiz referans kodu kaydı engellemez**: kod bulunamazsa, sahibi pasifse veya kendi koduysa kayıt tamamlanır, yalnızca referans oluşmaz. Uygulama, girişten sonra kullanıcıya "girdiğiniz kod geçerli değildi" uyarısı gösterir. (Kod doğrulaması kayıt öncesi yapılmaz; giriş yapmamış istemciye kod sorgulama açılmamıştır.)
2. Referans kodu yalnızca **kayıt sırasında** girilebilir; sonradan kod girme veya yöneticinin elle referans ekleme ekranı yoktur. Gerekirse sonraki adımda eklenebilir.
3. Yönetici, verdiği kararı sonradan değiştirebilir (onaylı ↔ reddedilmiş); her değişiklik denetim kaydına yazılır.
4. Sayım için getirilenin **herhangi bir kategoride** kullanılabilir tek paketi yeterlidir; paketin kalan hakkının 0 olması sayımı etkilemez (süresi dolana kadar aktif sayılır).
5. Gelecekte başlayacak bir dondurma sayımı etkilemez; referans yalnızca dondurma aralığı içindeyken sayımdan düşer.
6. İndirim, paketi **alan üyenin kendi** referans oranıdır (kod sahibi = paket atanan üye). Uygulanan oran 0 ile hak edilen oran arasında herhangi bir tam sayı olabilir; ekranda %5 adımlarıyla seçilir.
7. Daha önce atanmış paketlerin fiyatı, referans sayısı sonradan değişse de değişmez (atama anındaki oran saklanır).
8. Her rolden kullanıcının (eğitmen/yönetici dahil) referans kodu vardır; ancak indirim yalnızca paket atanabilen üyeler için anlamlıdır.
9. Getiren veya getirilen hesabın silinmesi halinde referans kaydı da silinir.

## 15. Yeni varsayımlar — onay bekliyor (adım 4: ders takvimi ve rezervasyon)

1. Giriş yapmış her aktif kullanıcı tüm planlanmış dersleri (kategori, eğitmen adı, kalan kontenjan) görür; üye ekranı bugünden itibaren **14 günü** listeler (yalnızca ekran sınırı; sunucu daha ileri tarihli derse rezervasyonu engellemez, paket geçerliliği kuralları geçerlidir).
2. Açılmış bir dersin saati/kategorisi/türü **düzenlenemez**; değişiklik için ders iptal edilip yeniden açılır.
3. Yönetici, ders detayından bir üyeyi derse **ekleyebilir** (üye adına rezervasyon; aynı kurallar ve hak düşümü uygulanır) (R-01).
4. Eğitmen katılımcıların yalnızca adını görür; rezervasyonları tek tek iptal edemez (yalnızca dersin tamamını iptal edebilir, S-06).
5. "Geldi / gelmedi" işaretleme (yoklama) bu adımda yoktur; adım 5 kapsamında ele alınacak (I-06).
6. Elle eklenen referansta getiren ve getirilen herhangi bir aktif kullanıcı olabilir (rol kısıtı yok); yönetici bu kaydı da sonradan reddedebilir (F-16, §14-3).
7. Üye "Geçmiş" sekmesinde iptal edilmiş rezervasyonlarını da görür; liste en son 300 rezervasyonla sınırlıdır.
