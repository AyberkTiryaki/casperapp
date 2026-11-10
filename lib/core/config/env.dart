/// Derleme zamanı yapılandırması. Değerler `--dart-define-from-file=env/dev.json`
/// ile verilir. Koda asla anahtar gömülmez; service_role anahtarı asla kullanılmaz.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
