# Google Play Console — form cevapları (16.11.2026)

Play Console > uygulama > **Uygulama içeriği** (Policy > App content) altındaki formlar için hazır cevaplar. Uygulamanın bugünkü davranışına göre hazırlandı; yeni bir özellik veri toplamayı değiştirirse güncellenmeli.

## 1. Gizlilik politikası
`https://gsenlik.github.io/casper-studio/gizlilik.html`

## 2. Uygulama erişimi (App access)
**"Uygulamanın tüm işlevleri veya bir kısmı kısıtlı"** seçilir → talimat ekle:

- Ad: `Üye hesabı`
- Kullanıcı adı: `uye1@casper.test`
- Şifre: `1234`
- Diğer bilgiler:
  > Uygulama bir spor stüdyosunun üyeleri içindir ve giriş gerektirir. Bu üye hesabında paketler, ders rezervasyonları, cüzdan, antrenman programı ve vücut ölçümleri deneme verisiyle doludur. Takvim sekmesinden derse rezervasyon yapılabilir. Giriş yapmadan "Paketleri keşfet" ile fiyatlar görülebilir.

## 3. Reklamlar
**Hayır**, uygulama reklam içermiyor.

## 4. İçerik derecelendirmesi (IARC anketi)
- E-posta: caspertrainingstudio@gmail.com
- Kategori: **Diğer tüm uygulama türleri** (Utility, Productivity, Communication or Other)
- Şiddet, cinsellik, küfür, uyuşturucu, kumar: hepsi **Hayır**
- Kullanıcılar birbiriyle etkileşim kuruyor / içerik paylaşıyor mu: **Hayır** (üyeler birbirini görmez)
- Kullanıcının konumunu paylaşıyor mu: **Hayır**
- Dijital ürün satın alımı: **Hayır** (cüzdan stüdyoda yüklenir, uygulama içi ödeme yok)
- Beklenen sonuç: **3+ / Herkes**

## 5. Hedef kitle ve içerik
- Hedef yaş grupları: **18 ve üzeri** (gizlilik politikası: 18 yaş altı yalnızca veli onayıyla stüdyo tarafından açılır)
- Uygulama çocukların ilgisini çekebilir mi: **Hayır**

## 6. Haber uygulaması
**Hayır**

## 7. Sağlık uygulamaları (Health apps declaration)
- Uygulamanın sağlık özellikleri var mı: **Evet**
- Seçilecek kategori: **Fitness / egzersiz ve aktivite takibi** (antrenman programı, kilo ve vücut ölçümü kaydı)
- Tıbbi cihaz / teşhis / tedavi: **Hayır**
- Health Connect kullanıyor mu: **Hayır**

## 8. Veri güvenliği (Data safety)

**Genel sorular**
- Uygulama gerekli kullanıcı verilerini topluyor veya paylaşıyor mu: **Evet**
- Toplanan tüm veriler aktarım sırasında şifreleniyor mu: **Evet** (HTTPS)
- Kullanıcıların veri silme talep etmesine imkan veriyor musunuz: **Evet** → `https://gsenlik.github.io/casper-studio/hesap-silme.html`
- Hesap oluşturma: **Kullanıcı adı ve şifre** (e-posta + şifre)

**Toplanan veriler.** Hiçbiri üçüncü tarafla **paylaşılmıyor**, hiçbiri **isteğe bağlı değil** (aksi belirtilmedikçe), işlenme amacı **Uygulama işlevselliği** ve **Hesap yönetimi**.

| Veri türü (Play adı) | Toplanıyor | Not |
|---|---|---|
| Kişisel bilgiler > Ad | Evet | |
| Kişisel bilgiler > E-posta adresi | Evet | |
| Kişisel bilgiler > Diğer bilgiler | Evet | doğum tarihi |
| Sağlık ve fitness > Fitness bilgileri | Evet | boy, kilo, antrenman programı. **İsteğe bağlı** |
| Sağlık ve fitness > Sağlık bilgileri | Evet | vücut ölçümleri (yağ oranı, çevre ölçüleri). **İsteğe bağlı**, açık rızayla |
| Finansal bilgiler > Satın alma geçmişi | Evet | paket ve ürün satışları, cüzdan hareketleri (stüdyoda yapılan) |
| Uygulama etkinliği > Uygulama içi işlemler | Evet | ders rezervasyonları ve katılım |
| Konum, kişiler, fotoğraf, dosya, mesaj, takvim, ses | **Hayır** | |
| Cihaz veya diğer kimlikler | **Hayır** | bildirimler cihazda yerel üretilir, cihaz anahtarı toplanmaz |
| Uygulama bilgileri ve performansı (kilitlenme raporu) | **Hayır** | hata takibi servisi yok |

**Güvenlik uygulamaları:** veriler aktarımda şifreli; kullanıcı silme talep edebilir. "Bağımsız güvenlik incelemesi" **Hayır**.

## 9. Devlet uygulaması / finans özellikleri
- Devlet uygulaması: **Hayır**
- Finansal özellikler: **Hiçbiri** (cüzdan yalnızca stüdyo içi bakiye takibidir; ödeme, kredi, yatırım yok). Play "uygulama içinde para tutma" sorarsa: uygulama para tutmaz, stüdyo bakiyesini gösterir.

## 10. Mağaza girişi
- Uygulama adı, kısa ve uzun açıklama: `docs/MAGAZA_METNI.md`
- Kategori: **Sağlık ve Fitness**
- E-posta: caspertrainingstudio@gmail.com · Web sitesi: https://www.instagram.com/caspertrainingstudio/
- Görseller: `store/play/` (`flutter test tool/store_shots` ile üretilir)
  - Uygulama simgesi 512×512: `simge_512.png`
  - Tanıtım görseli 1024×500: `tanitim_1024x500.png`
  - Telefon ekran görüntüleri (1080×2340): `01_…` – `06_…`

## 11. Kapalı test (kişisel hesap şartı)
Yeni kişisel geliştirici hesaplarında **üretime çıkmadan önce en az 12 test kullanıcısı 14 gün boyunca kapalı teste katılmalıdır**.

1. Test ve yayın > Test > **Kapalı test** > yeni kanal (ör. "Pilot").
2. **Test kullanıcıları**: e-posta listesi oluşturun (Gmail / Google hesabı adresleri). Eğitmenler, yönetici ve en az 9 gönüllü üye.
3. CI'ın ürettiği `casper-play-aab` dosyasını (`casper-play-<no>-<sha>.aab`) sürüme yükleyin.
4. Katılım bağlantısını test kullanıcılarına gönderin; kabul edip Play Store'dan kurmaları gerekir.
5. 14 gün boyunca en az 12 kişi katılımda kalmalı. Sonra **Üretime erişim başvurusu** formu doldurulur.

## Yayından önce yapılacaklar
- `yonetici@casper.test` şifresini 1234'ten değiştirin (Profil ekranı veya Supabase).
- Gerçek eğitmen ve yönetici hesaplarını açın.
- Gizlilik politikasında "Son güncelleme" tarihini yayın günüyle güncelleyip sayfayı yeniden üretin (`python web/legal/build.py`).
