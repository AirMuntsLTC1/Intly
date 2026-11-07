/// Supabase connection for Intly.
///
/// [anonKey] is the publishable key. It is not stored in this file: the
/// build passes it in from the GitHub secret SUPABASE_PUBLISHABLE_KEY
/// (see .github/workflows/build.yml). It is public by design and safe in the app.
/// NEVER use the service_role or secret key.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://ysjyyhgzhpdtdtrwqqwk.supabase.co';

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Set to true by main.dart once Supabase has started.
  static bool ready = false;

  /// Why Supabase failed to start, if it did (shown on the setup screen).
  static String? startError;

  static bool get keyIsSet => anonKey.isNotEmpty;
}
