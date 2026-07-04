import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _supabaseReady = false;

bool get isSupabaseReady => _supabaseReady;

Future<void> configureSupabase() async {
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  try {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _supabaseReady = true;
  } catch (error) {
    _supabaseReady = false;
    if (kDebugMode) {
      debugPrint('Supabase initialization failed: $error');
    }
  }
}

SupabaseClient get supabase => Supabase.instance.client;
