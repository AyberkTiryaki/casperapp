import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/async_value_view.dart' show isNetworkError;

const _serverCodeMessages = <String, String>{
  'FORBIDDEN': 'Bu işlem için yetkiniz yok.',
  'UNAUTHENTICATED': 'Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.',
  'IDEMPOTENCY_KEY_REQUIRED': 'İşlem anahtarı eksik. Lütfen tekrar deneyin.',
  'IDEMPOTENCY_KEY_REUSED':
      'Bu işlem anahtarı farklı bir işlemde kullanılmış. Lütfen işlemi baştan başlatın.',
  'MEMBER_NOT_ELIGIBLE': 'Bu üyeye paket tanımlanamaz (aktif bir üye değil).',
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
  'DISCOUNT_EXCEEDS_ENTITLEMENT':
      'İndirim, üyenin güncel referans indirimi hakkını aşıyor. Lütfen oranı yenileyip tekrar deneyin.',
  'REFERRAL_NOT_FOUND': 'Referans kaydı bulunamadı.',
  'DECISION_REQUIRED': 'Bu işlem için bir karar (onay/ret) belirtilmeli.',
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
    return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
  }
  return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
}
