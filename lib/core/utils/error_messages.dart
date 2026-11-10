import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/async_value_view.dart' show isNetworkError;

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
    if (e.code == '42501') return 'Bu işlem için yetkiniz yok.';
    return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
  }
  return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
}
