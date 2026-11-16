# Mağaza Metni — Taslak

Durum: **taslak**. Stüdyo onayından sonra Google Play Console ve App Store Connect'e girilir. Karakter sınırları parantez içinde.

## Uygulama adı
- Google Play (30): `Casper Training Studio`
- App Store (30): `Casper Training Studio`
- App Store alt başlık (30): `Ders rezervasyonu ve paketler`

## Kısa açıklama — yalnızca Google Play (80)
Casper Training Studio üyeleri için ders rezervasyonu, paket ve bakiye takibi.

## Uzun açıklama (4000)
Casper Training Studio uygulaması stüdyomuzun üyeleri, eğitmenleri ve yöneticileri içindir. Ders programını görün, yerinizi ayırın, paketinizi ve bakiyenizi takip edin.

**Üyeler için**
- Önümüzdeki günlerin derslerini kategori, eğitmen ve kalan kontenjanla görün
- Tek dokunuşla rezervasyon yapın; dersten en az 2 saat önce iptal edip hakkınızı geri alın
- Aktif paketlerinizi, kalan ders haklarınızı ve bitiş tarihlerini izleyin
- Cüzdan bakiyenizi ve harcama geçmişinizi görün
- Eğitmeninizin hazırladığı antrenman programına ve vücut ölçümlerinize ulaşın
- Referans kodunuzla arkadaşlarınızı davet edin, indirim oranınızı takip edin

**Eğitmenler için**
- Kendi takviminizi görün, bireysel veya grup dersi açın
- Derse kayıtlı üyeleri görün
- Üyelerinize program hazırlayın, ölçümlerini kaydedin
- Stüdyo ürünlerinin satışını üyenin bakiyesinden yapın

**Yöneticiler için**
- Paket tanımlama, atama, yenileme ve dondurma
- Ders ve rezervasyon yönetimi
- Bakiye yükleme ve işlem geçmişi
- Referans onayı ve raporlar

Uygulama yalnızca Casper Training Studio üyeleri içindir. Hesabınız stüdyomuzda açılır ya da uygulamadan kayıt olabilirsiniz.

## Anahtar kelimeler — yalnızca App Store (100, virgülle)
`atletik performans,özel ders,personal trainer,fitness,stüdyo,rezervasyon,antrenman,spor,eğitmen,grup dersi`

> Kategoriler 14.11.2026 itibarıyla: Atletik Özel Ders, Atletik Performans Grup, Özel Ders.

## Kategori
- Google Play: Sağlık ve Fitness
- App Store: Sağlık ve Fitness (Health & Fitness)

## İletişim ve bağlantılar (stüdyo dolduracak)
- Destek e-postası: caspertrainingstudio@gmail.com
- Web sitesi: https://www.instagram.com/caspertrainingstudio/ (stüdyonun web sitesi yok; Play Store web sitesi alanına ve App Store "Marketing URL" alanına bu adres girilir)
- Gizlilik politikası URL'si: https://gsenlik.github.io/casper-studio/gizlilik.html
- Hesap silme sayfası URL'si: https://gsenlik.github.io/casper-studio/hesap-silme.html

Bu iki sayfa herkese açık `gsenlik/casper-studio` deposunda GitHub Pages ile yayınlanır (16.11.2026). Kaynak: `docs/GIZLILIK_POLITIKASI.md` ve `web/legal/hesap-silme.md`; `python web/legal/build.py` ile üretilip o depoya gönderilir. Gizlilik metni değişince sayfa da güncellenmelidir.

## İnceleme ekibi için not (App Store Review / Play)
Uygulama girişi gerektirir. İnceleme hesapları (`supabase/seed/play_review_reset.sql`, 16.11.2026):
- Üye: `uye1@casper.test` / `1234` (paketli, rezervasyonlu, programı ve ölçümü olan hesap)
- Eğitmen: `egitmen1@casper.test` / `1234`

Play Console > Uygulama içeriği > Uygulama erişimi alanına girilecek not:
"Uygulama stüdyo üyeleri içindir ve giriş gerektirir. Üye hesabı ile giriş yapın: uye1@casper.test / 1234. Ders takvimi, rezervasyon, paketler, cüzdan, antrenman programı ve ölçümler bu hesapta deneme verisiyle doludur. Kayıt ol ekranından yeni hesap da açılabilir."

Bu hesaplar canlı ortamdadır; içinde gerçek üye verisi yoktur. Yayından önce yönetici hesabının (`yonetici@casper.test`) şifresi değiştirilmelidir.

## Ekran görüntüleri (çekilecek)
Telefon: en az 2 (Play), 6,7" ve 6,5" iPhone için (App Store). Önerilen sıra:
1. Üye ana sayfası (paket ve bakiye)
2. Ders takvimi ve rezervasyon
3. Paketlerim / kalan haklar
4. Antrenman programım
5. Eğitmen takvimi
6. Yönetici ana sayfası

Ekran görüntüleri inceleme verisiyle (`supabase/seed/play_review_reset.sql`) çekilir; gerçek üye adı görünmez.

## Veri güvenliği formu (Google Play) / Gizlilik etiketi (App Store) — özet
Toplanan veriler: ad soyad, e-posta, doğum tarihi, boy, kilo, vücut ölçümleri (sağlık/fitness), uygulama içi işlem kayıtları (rezervasyon, bakiye hareketi). Reklam ya da üçüncü tarafla paylaşım yok, takip yok. Veriler aktarım sırasında şifrelenir (HTTPS). Kullanıcı hesap silme talep edebilir.
