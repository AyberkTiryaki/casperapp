/// Stüdyonun iletişim bilgileri: tek yerden değiştirilir.
class Studio {
  static const name = 'Casper Training Studio';
  static const address =
      'Atatürk Mah., Ahmet Karaevli Sk., Pilatin Prime Sitesi 7/A No: 19, '
      'Süleymanpaşa / Tekirdağ';
  static const email = 'caspersporkulubu@gmail.com';

  /// Salon sahibinin telefonu (arama ve WhatsApp).
  static const phoneDisplay = '+90 531 013 23 17';
  static const phoneUrl = 'tel:+905310132317';
  static const whatsappUrl = 'https://wa.me/905310132317';
  static const emailUrl = 'mailto:$email';
  static const instagramUrl = 'https://www.instagram.com/caspertrainingstudio/';

  /// Google Haritalar arama bağlantısı: telefonda harita uygulamasını, yoksa tarayıcıyı açar.
  static final mapsUrl =
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeQueryComponent('Pilatin Prime Sitesi, Ahmet Karaevli Sokak, Atatürk Mahallesi, Süleymanpaşa, Tekirdağ')}';
}
