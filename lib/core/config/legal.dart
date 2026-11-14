/// KVKK metinleri. Metin değiştiğinde sürüm numarası artırılır (K-04).
///
/// DURUM: Claude tarafından hazırlanmış taslak (14.11.2026). Yayından önce
/// hukuk danışmanı tarafından gözden geçirilmeli; [ ] içindeki stüdyo bilgileri
/// doldurulmalıdır. Ayrıntı: docs/KVKK_NOTLARI.md
const kvkkTextVersion = '2026-11-v2';

/// Sağlık verisi açık rıza metninin sürümü (aydınlatma metninden ayrı onaylanır).
const healthConsentTextVersion = '2026-11-v1';

const kvkkText = '''
CASPER TRAINING STUDIO
KİŞİSEL VERİLERİN İŞLENMESİNE İLİŞKİN AYDINLATMA METNİ

1. Veri sorumlusu
6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca kişisel verileriniz, veri sorumlusu sıfatıyla Casper Training Studio ("Stüdyo") tarafından aşağıda açıklanan kapsamda işlenmektedir.
Adres: Atatürk Mahallesi, Ahmet Karaevli Sokak, Pilatin Prime Sitesi 7/A No: 19, Süleymanpaşa / Tekirdağ
E-posta: [E-posta adresi]

2. İşlenen kişisel veriler
• Kimlik: ad soyad, doğum tarihi
• İletişim: e-posta adresi
• Fiziksel ve sağlık bilgileri: boy, kilo; eğitmeninizin kaydettiği vücut ölçümleri (kilo, yağ oranı, kas kütlesi, bel, kalça, göğüs, kol, bacak ölçüleri ve ölçüm notları)
• Müşteri işlem bilgileri: üyelik paketleri, ders rezervasyonları ve katılım durumu, cüzdan bakiyesi ve hareketleri, ürün satışları, referans kodu ve referans kayıtları, antrenman programlarınız
• İşlem güvenliği bilgileri: giriş kayıtları, IP adresi, uygulama içinde yapılan işlemlerin kayıtları, bildirim için cihaz anahtarı
• Onay kayıtları: bu metnin ve açık rıza metninin onaylandığı sürüm ve tarih

Kronik rahatsızlık, tanı veya tedavi bilgisi istenmez ve işlenmez.

3. İşleme amaçları ve hukuki sebepler
a) Üyeliğinizin kurulması, paketlerinizin tanımlanması, ders rezervasyonu, iptal ve iade işlemlerinin yürütülmesi, cüzdan ve ürün satışlarının kaydı, referans indiriminin hesaplanması ve size bilgilendirme bildirimleri gönderilmesi: bir sözleşmenin kurulması veya ifasıyla doğrudan ilgili olması (KVKK md. 5/2-c).
b) Mali kayıtların tutulması ve yetkili kurumların taleplerinin karşılanması: hukuki yükümlülüğün yerine getirilmesi (md. 5/2-ç).
c) Hesap ve işlem güvenliğinin sağlanması, hatalı işlemlerin tespiti ve düzeltilmesi, hizmetin raporlanması ve iyileştirilmesi: temel hak ve özgürlüklerinize zarar vermemek kaydıyla Stüdyonun meşru menfaati (md. 5/2-f).
d) Size uygun antrenman programı hazırlanması ve gelişiminizin izlenmesi amacıyla vücut ölçümlerinizin işlenmesi: ayrıca vereceğiniz açık rıza (md. 6/3). Açık rıza vermemeniz üyeliğinizi ve ders rezervasyonu yapmanızı etkilemez; bu durumda vücut ölçümünüz kaydedilmez.

4. Toplama yöntemi
Verileriniz mobil uygulama üzerinden sizin girdiğiniz bilgilerle ve Stüdyo yöneticisi ile eğitmenlerinin uygulamaya kaydettiği bilgilerle elektronik ortamda toplanır.

5. Kimlerin erişebildiği ve aktarım
• Stüdyo içinde: yöneticiler tüm üyelik bilgilerine; eğitmenler yalnızca derslerine katılan üyelerin ders, program ve ölçüm bilgilerine görevleri gereği erişir.
• Referans sistemi: kodunuzla kayıt olan kişiler yalnızca adınızı ve soyadınızın baş harfini görür; siz de getirdiğiniz kişiler için yalnızca bu bilgiyi ve referans durumunu görürsünüz.
• Yurt içi: talep halinde kanunen yetkili kamu kurum ve kuruluşları.
• Yurt dışı: uygulamanın çalışması için hizmet aldığımız altyapı sağlayıcıları: veritabanı ve kimlik doğrulama (Supabase; sunucular Avrupa Birliği'nde, İsveç), telefon bildirimleri (Google Firebase) ve e-posta gönderimi sağlayıcısı. Bu aktarımlar KVKK md. 9'da öngörülen güvencelere uygun olarak yapılır.
Verileriniz reklam amacıyla kullanılmaz ve satılmaz.

6. Saklama süresi
Verileriniz hesabınız açık olduğu sürece saklanır. Hesap silme talebinizden sonra kimlik, iletişim, ölçüm ve program bilgileriniz silinir veya anonim hale getirilir. Satış ve bakiye hareketleri gibi mali kayıtlar ilgili mevzuatın öngördüğü süre (10 yıla kadar) boyunca saklanır ve bu sürenin sonunda silinir.

7. Haklarınız (KVKK md. 11)
Kişisel verilerinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, işleme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme, aktarıldığı üçüncü kişileri bilme, eksik veya yanlış işlenmişse düzeltilmesini, silinmesini veya yok edilmesini isteme, bu işlemlerin aktarılan kişilere bildirilmesini isteme, otomatik analiz sonucu aleyhinize bir sonuca itiraz etme ve kanuna aykırı işleme nedeniyle zarara uğramanız halinde zararın giderilmesini talep etme haklarına sahipsiniz. Açık rızanızı dilediğiniz zaman geri alabilirsiniz.

Başvurularınızı yukarıdaki adrese yazılı olarak veya kayıtlı e-posta adresinizden [E-posta adresi] adresine iletebilirsiniz. Hesabınızın silinmesini uygulamadaki Profil > "Hesabımı sil" ile de isteyebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır.
''';

const healthConsentText = '''
SAĞLIK VERİLERİ AÇIK RIZA METNİ

Aydınlatma Metni'ni okudum. Eğitmenimin veya benim kaydedeceğim vücut ölçümlerimin (kilo, yağ oranı, kas kütlesi, çevre ölçüleri ve ölçüm notları) bana uygun antrenman programı hazırlanması ve gelişimimin izlenmesi amacıyla Casper Training Studio tarafından işlenmesine, Stüdyo yöneticileri ile derslerime giren eğitmenlerin görmesine ve bu verilerin uygulamanın altyapı sağlayıcısının yurt dışındaki (Avrupa Birliği) sunucularında saklanmasına açık rızam ile onay veriyorum.

Bu onayı vermemem üyeliğimi ve ders rezervasyonu yapmamı etkilemez. Onayımı dilediğim zaman Stüdyoya başvurarak geri alabilirim; geri almam halinde ölçümlerim silinir.
''';
