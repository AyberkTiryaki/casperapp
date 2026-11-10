# Casper Training Studio — Flutter + Supabase Yol Haritası

Kaynak: "Casper_Training_Studio_Flutter_Supabase_Yol_Haritasi.pdf" (10 Kasım 2026).

Amaç: Tek şubeli stüdyonun üyelik paketleri, ders rezervasyonları ve cüzdan işlemleri tek mobil uygulamada. Üye, eğitmen ve yönetici aynı uygulamaya giriş yapar; role uygun ekranları görür.

## 1. Mimari
- Mobil: Flutter (iOS + Android)
- Giriş: Supabase Auth (e-posta + şifre)
- Veritabanı: Supabase PostgreSQL
- Erişim: RLS ile kullanıcı ve rol bazlı
- İş kuralları: PostgreSQL fonksiyonları, tek transaction
- Sunucu: Gerektiğinde Edge Functions + zamanlanmış görevler
- Bildirim: Mobil push servisi

## 2. Altyapı
- Flutter projesi, Git, düzenli klasör yapısı
- Geliştirme / canlı ortam ayrımı; DB değişiklikleri migration dosyalarıyla
- Casper renkleri, yazı stilleri, ortak bileşenler
- Yükleniyor / boş liste / hata / bağlantı kesildi durumları
- **Bitti ölçütü:** Uygulama açılır, Supabase bağlantısı çalışır, giriş ekranına ulaşılır.

## 3. Veritabanı
| Grup | Bilgiler |
|---|---|
| Profiller ve roller | Ad soyad, doğum tarihi, boy, güncel kilo; üye / eğitmen / yönetici |
| Kategori ve paket tanımları | Kategori, ders sayısı, fiyat, geçerlilik süresi |
| Üye paketleri | Aktivasyon, bitiş, durum, hak bilgileri |
| Dersler | Eğitmen, kategori, tarih, saat, kapasite |
| Rezervasyonlar | Üye, ders, kullanılan paket, durum |
| Hak hareketleri | Hak düşme, iade, aktarım, düzeltme |
| Dondurma kayıtları | Paket, tarih aralığı, işlemi yapan yönetici |
| Ürün ve satışlar | Ürün, fiyat, satış anındaki fiyat |
| Cüzdan hareketleri | Yükleme, harcama, ters kayıt, düzeltme |
| Onay ve işlem kayıtları | KVKK metin sürümü, onay tarihi, işlemi yapan |
| Bildirimler | Cihaz bağlantıları, gönderim sonuçları |

## 4. Kayıt ve profil
- E-posta/şifre ile kayıt, giriş, çıkış, e-posta doğrulama, şifre sıfırlama
- Ad soyad, boy, kilo, doğum tarihi. **Kronik rahatsızlık alanı YOK.**
- KVKK onayı metin sürümü + tarih ile kaydedilir
- Profilde sadece güncel kilo
- Hesap silme talebi ve veri süreci

## 5. Yetkilendirme
Üye kendi verisine erişir. Eğitmen ders ve satış için gereken veriye erişir. Yönetici paket, cüzdan ve kullanıcı yönetimi yapar. Eğitmen/yönetici rolleri sadece yetkili işlemle atanır.
- **Bitti ölçütü:** Rol kontrolü hem ekranda hem Supabase'de çalışır; kimse başka üyenin verisini göremez. **Service role anahtarı mobil uygulamaya asla konmaz.**

## 6. Paket yönetimi
- Yönetici paket tanımlar ve üyeye atar; fiyatlar yönetim ekranından değişir
- Paket sadece kendi kategorisinde kullanılır
- Aynı kategoride tek aktif paket; farklı kategoriler aynı anda aktif olabilir
- 8 ve 12 derslik: aktivasyondan itibaren 30 gün; 16 ve 20 derslik: 40 gün
- Fiyat değişikliği önceden atanmış paketleri etkilemez
- Yönetici eski paketi erken bitirip yenisini aktif edebilir; uygun gelecek rezervasyonlar yeni pakete aktarılır

## 7. Ders ve takvim
Eğitmen kendi takvimini görür, bireysel veya grup dersi açar, katılımcıları görür. Bireysel kapasite 1, grup kapasite 6. Üye tarihe ve kategoriye göre dersleri, eğitmeni ve kalan kontenjanı görür.

## 8. Rezervasyon
- Kontenjan, kategori, geçerlilik ve kalan hak kontrolü sunucuda yapılır
- Aynı derse ikinci rezervasyon engellenir
- Rezervasyon + hak düşme tek DB işleminde
- Eşzamanlı isteklerde son kontenjan tek üyeye verilir
- Tekrarlanan istek ikinci rezervasyon veya ikinci düşüm yaratmaz (idempotency)
- Üye aktif paketleri, kalan hakları, gelecek ve geçmiş rezervasyonları görür
- **Açık karar:** Paket geçerliliği rezervasyon anını ve ders tarihini de kapsamalı (önerilen; kesinleşecek)

**İlk uçtan uca akış:** Yönetici paket atar → eğitmen ders açar → üye rezervasyon yapar → hak düşer → zamanında iptal edilirse hak geri gelir. Gerçek cihazda ve eşzamanlı isteklerde tutarlı olmalı.

## 9. İptal ve paket işlemleri
| Durum | Davranış |
|---|---|
| Üye en az 2 saat kala iptal eder | İptal edilir, hak iade edilir |
| Derse 2 saatten az kaldı | Üye iptal edemez (ekran + sunucu kontrol eder) |
| Yönetici iptal eder | Her zaman iptal edebilir; hak iadesini kendisi seçer |
| Üye derse gelmez | Ek otomatik düşüm yok; düşülen hak kalır. Gerekirse yönetici manuel işlem kaydeder |
| Paket dondurulur | Sadece yönetici. Dondurma dönemindeki gelecek rezervasyonlar iptal edilir, haklar iade edilir |
| Paket yenilenir | Eski haklar biter; uygun gelecek rezervasyonlar yeni pakete aktarılır |

**Açık karar:** Dondurma süresi paket bitiş tarihine eklenecek mi? Aktarımda yeni paketin hakkı ve ders tarihine uygunluğu kontrol edilmeli.

## 10. Cüzdan ve ürün satışı
- Yönetici bakiye yükler; ödeme yöntemi kaydı tutulmaz
- Üye bakiyesini ve hareketlerini görür
- Eğitmen ürün seçip üyeye satar; yetersiz bakiyede satış engellenir
- Satış fiyatı işlem anındaki değerle saklanır
- Hatalı işlem silinmez; yönetici ters kayıt veya düzeltme hareketi girer
- Üyelik bitse de bakiye kullanılabilir
- Kapsam dışı: stok takibi, QR, üye onayı
- **Bitti ölçütü:** Eşzamanlı harcamalar bakiyeyi eksiye düşürmez; aynı satış iki kez işlenmez; her bakiye değişiminin hareket kaydı var.

## 11. Yönetim ekranları (mobil uygulama içinde)
Üye arama ve detay, paket atama/yenileme, dondurma, ders ve rezervasyon yönetimi, eğitmen yönetimi, ürün ve fiyat yönetimi, bakiye yükleme, işlem geçmişleri.

## 12. Bildirimler
Rezervasyon onayı, ders iptali, ders hatırlatması, paket bitiş uyarısı. Cihaz izinleri, gönderim sonuçları, aynı bildirimin tekrarlanmaması.

## 13. Test ve pilot
- Son kontenjana eşzamanlı rezervasyon; bağlantı sonrası tekrarlanan istek
- Tam 2 saat sınırında iptal; süresi veya hakkı bitmiş paket
- Dondurma ve yenileme sırasında gelecek rezervasyonlar
- Eşzamanlı cüzdan harcaması, yetersiz bakiye, hatalı satış düzeltmesi
- Üyenin başka üyenin verisine, eğitmenin yönetici işlemlerine erişememesi
- Gerçek iPhone ve Android cihazda giriş, takvim, bildirim
- Pilot: 3 eğitmen + küçük üye grubu; sonra mağaza başvurusu

## 14. Yayın hazırlığı
İkon, açılış ekranı, mağaza metni ve ekran görüntüleri; gizlilik politikası, kullanıcı metinleri, hesap silme; canlı ortam, yedekleme, hata takibi, e-posta ayarları; iOS/Android imzalama, test dağıtımı, mağaza başvurusu; yönetici kullanım kılavuzu.

## Teslim sırası
1. Ekran akışları, kesin iş kuralları, veritabanı tasarımı
2. Altyapı, kayıt, giriş, roller
3. Paket yönetimi
4. Ders takvimi ve rezervasyon
5. İptal, dondurma, yenileme
6. Cüzdan, ürün satışı, yönetim ekranları
7. Bildirimler, testler, pilot
8. Mağaza hazırlığı ve yayın
