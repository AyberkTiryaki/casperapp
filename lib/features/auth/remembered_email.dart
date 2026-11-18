import 'package:shared_preferences/shared_preferences.dart';

/// "Beni hatırla": giriş ekranında yalnızca e-posta hatırlanır, şifre hiçbir
/// zaman saklanmaz.
const _prefsKey = 'remembered_email';

Future<String?> loadRememberedEmail() async {
  try {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_prefsKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

Future<void> saveRememberedEmail(String? email) async {
  try {
    final p = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await p.remove(_prefsKey);
    } else {
      await p.setString(_prefsKey, email);
    }
  } catch (_) {}
}
