import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _supabaseReady = false;

bool get isSupabaseReady => _supabaseReady;

Future<void> configureSupabase() async {
  // Load .env file (flutter_dotenv)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Warning: .env load failed ($e) — trying fallback');
    }
  }

  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (kDebugMode) {
    debugPrint('Supabase URL loaded: ${url.isNotEmpty ? "yes" : "NO"}');
    debugPrint('Supabase Key loaded: ${anonKey.isNotEmpty ? "yes" : "NO"}');
  }

  if (url.isEmpty || anonKey.isEmpty) {
    _supabaseReady = false;
    if (kDebugMode) {
      debugPrint(
        'Supabase init aborted — URL or anon key is empty. '
        'Check your .env file is bundled as a Flutter asset.',
      );
    }
    return;
  }

  try {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        // PKCE is required for secure auth on all platforms.
        // The Android intent-filter for the deep link
        // (io.supabase.flutter://login-callback) is configured
        // in android/app/src/main/AndroidManifest.xml.
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _supabaseReady = true;
    if (kDebugMode) {
      debugPrint('Supabase initialized successfully');
    }
  } catch (error) {
    _supabaseReady = false;
    if (kDebugMode) {
      debugPrint('Supabase initialization failed: $error');
    }
  }
}

SupabaseClient get supabase => Supabase.instance.client;
