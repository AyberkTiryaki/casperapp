import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/async_value_view.dart' show isNetworkError;

const _serverCodeMessages = <String, String>{
  'FORBIDDEN': 'Bu işlem için yetkiniz yok.',
  'UNAUTHENTICATED': 'Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.',
  'IDEMPOTENCY_KEY_REQUIRED': 'İşlem anahtarı eksik. Lütfen tekrar deneyin.',
  'IDEMPOTENCY_KEY_REUSED': 'Bu işlem anahtarı farklı bir işlemde kullanılmış. Lütfen işlemi baştan başlatın.',
  'MEMBER_NOT_ELIGIBLE':
      'Bu işlem için üye uygun değil (aktif bir üye olmalı).',
  'DEFINITION_NOT_FOUND': 'Paket tanımı bulunamadı veya pasif.',
  'ACTIVE_PACKAGE_EXISTS': 'Bu kategoride zaten aktif bir paket var.',
  'PACKAGE_NOT_FOUND': 'Paket bulunamadı.',
  'PACKAGE_NOT_ACTIVE': 'Paket aktif değil.',
  'INVALID_FREEZE_RANGE': 'Dondurma tarih aralığı geçersiz.',
  'FREEZE_IN_PAST': 'Dondurma başlangıcı geçmişte olamaz.',
  'FREEZE_OUTSIDE_PACKAGE':
      'Dondurma aralığı paketin geçerlilik süresi dışında kalıyor.',
  'FREEZE_OVERLAP': 'Bu tarihlerde zaten bir dondurma var.',
  'USER_NOT_FOUND': 'Kullanıcı bulunamadı.',
  'INVALID_DISCOUNT': 'İndirim oranı geçersiz.',
  'DISCOUNT_EXCEEDS_ENTITLEMENT': 'İndirim, üyenin güncel referans indirimi hakkını aşıyor. Lütfen oranı yenileyip tekrar deneyin.',
  'REFERRAL_NOT_FOUND': 'Referans kaydı bulunamadı.',
  'DECISION_REQUIRED': 'Bu işlem için bir karar (onay/ret) belirtilmeli.',
  'ALREADY_BOOKED': 'Bu derse zaten rezervasyonunuz var.',
  'CANCEL_WINDOW_CLOSED':
      'Dersin başlamasına 2 saatten az kaldığı için iptal edilemez.',
  'CATEGORY_NOT_FOUND': 'Kategori bulunamadı veya pasif.',
  'CLASS_AFTER_PACKAGE_END': 'Ders, paketinizin bitiş tarihinden sonra.',
  'CLASS_ALREADY_STARTED': 'Ders başlamış olduğu için bu işlem yapılamaz.',
  'CLASS_CANCELLED': 'Bu ders iptal edilmiş.',
  'CLASS_FULL': 'Ders dolu.',
  'CLASS_NOT_FOUND': 'Ders bulunamadı.',
  'INVALID_CLASS_TIME': 'Ders zamanı geçersiz (geçmişte olamaz).',
  'INVALID_DURATION': 'Ders süresi geçersiz.',
  'NO_ACTIVE_PACKAGE': 'Bu kategoride aktif paketiniz yok.',
  'NO_CREDITS': 'Paketinizde kalan ders hakkı yok.',
  'PACKAGE_EXPIRED': 'Paketinizin süresi dolmuş.',
  'PACKAGE_FROZEN': 'Paketiniz dondurulmuş durumda.',
  'REFUND_CHOICE_REQUIRED': 'Hak iadesi tercihi belirtilmeli.',
  'RESERVATION_NOT_FOUND': 'Rezervasyon bulunamadı veya iptal edilmiş.',
  'TRAINER_BUSY': 'Antrenörün bu saatte başka bir dersi var.',
  'TRAINER_NOT_FOUND': 'Antrenör bulunamadı.',
  'TRAINER_REQUIRED': 'Antrenör seçilmeli.',
  'FREEZE_NOT_FOUND': 'Dondurma kaydı bulunamadı.',
  'FREEZE_ALREADY_ENDED': 'Bu dondurma zaten sona ermiş.',
  'INVALID_CREDIT_DELTA': 'Hak değişimi 1 ile 100 arasında olmalı.',
  'NOTE_REQUIRED': 'Not girmek zorunludur.',
  'CLASS_NOT_STARTED': 'Ders henüz başlamadığı için bu işlem yapılamaz.',
  'INVALID_AMOUNT': 'Tutar geçersiz.',
  'INVALID_QUANTITY': 'Adet 1 ile 100 arasında olmalı.',
  'INSUFFICIENT_BALANCE': 'Cüzdan bakiyesi yetersiz.',
  'PRODUCT_NOT_FOUND': 'Ürün bulunamadı veya satışa kapalı.',
  'ENTRY_NOT_FOUND': 'Cüzdan hareketi bulunamadı.',
  'CANNOT_REVERSE_REVERSAL': 'Ters kayıt tekrar ters çevrilemez.',
  'ALREADY_REVERSED': 'Bu hareket zaten ters çevrilmiş.',
  'CANNOT_DEMOTE_SELF': 'Kendi rolünüzü değiştiremezsiniz.',
  'CANNOT_DEACTIVATE_SELF': 'Kendi hesabınızı pasif yapamazsınız.',
  'RESERVATION_NOT_ACTIVE': 'Rezervasyonun durumu bu işleme uygun değil.',
  'EMAIL_ALREADY_REGISTERED': 'Bu e-posta adresiyle zaten bir hesap var.',
  'INVALID_EMAIL': 'Geçerli bir e-posta girin.',
  'WEAK_PASSWORD': 'Şifre çok kısa veya sunucu tarafından kabul edilmedi.',
  'INVALID_FULL_NAME': 'Ad soyad geçersiz.',
  'INVALID_INPUT': 'Girilen bilgiler geçersiz.',
  'CREATE_USER_FAILED': 'Hesap oluşturulamadı. Lütfen tekrar deneyin.',
  'PROGRAM_NOT_FOUND': 'Antrenman programı bulunamadı.',
  'INVALID_DATE': 'Tarih geçersiz (gelecekte olamaz).',
  'MEASUREMENT_EMPTY': 'En az bir ölçüm değeri girin.',
  'MEASUREMENT_NOT_FOUND': 'Ölçüm bulunamadı veya silme yetkiniz yok.',
  'INVALID_DATE_RANGE': 'Tarih aralığı geçersiz (en fazla 366 gün).',
  'HEALTH_CONSENT_REQUIRED':
      'Bu üyenin sağlık verisi onayı yok; ölçüm kaydedilemez. Üye onayı Profil ekranından verebilir.',
  'ROLE_UPDATE_FAILED': 'Hesap açıldı ancak rol atanamadı. Rolü kullanıcı listesinden değiştirin.',
};

String friendlyError(Object e) {
  if (isNetworkError(e)) {
    return 'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin.';
  }
  if (e is AuthException) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'E-posta adresiniz henüz doğrulanmamış. Lütfen gelen kutunuzu kontrol edin.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered')) {
      return 'Bu e-posta adresiyle zaten bir hesap var.';
    }
    if (code == 'weak_password' || msg.contains('password should')) {
      return 'Şifre çok zayıf. En az 8 karakterli daha güçlü bir şifre seçin.';
    }
    if (code.contains('rate_limit') ||
        msg.contains('rate limit') ||
        e.statusCode == '429') {
      return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
    }
    if (code == 'same_password') {
      return 'Yeni şifre eskisiyle aynı olamaz.';
    }
    return 'İşlem gerçekleştirilemedi. Lütfen tekrar deneyin.';
  }
  if (e is PostgrestException) {
    final known = _serverCodeMessages[e.message.trim()];
    if (known != null) return known;
    if (e.code == '23505') return 'Bu kayıt zaten var.';
    if (e.code == '23514') return 'Girilen değerler kurallara uymuyor.';
    if (e.code == '42501') return 'Bu işlem için yetkiniz yok.';
    // Uygulama sunucudan yeni bir fonksiyon istiyor ama veritabanı güncellemesi yüklenmemiş
    if (e.code == 'PGRST202') {
      return 'Bu özellik için sunucu güncellemesi henüz yüklenmedi.';
    }
    return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
  }
  return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
}
