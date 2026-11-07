/// Supabase connection for Intly.
///
/// [url] is your project (Intly-db).
///
/// [anonKey]: paste the anon / publishable key from
///   Supabase Dashboard > Project Settings > API.
///   It is public by design and is safe inside the app.
///   NEVER paste the service_role or secret key here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://ysjyyhgzhpdtdtrwqqwk.supabase.co';

  static const String anonKey = 'PASTE_YOUR_ANON_KEY_HERE';

  /// Set to true by main.dart once Supabase has started.
  static bool ready = false;

  static bool get keyIsSet => !anonKey.startsWith('PASTE_');
}
