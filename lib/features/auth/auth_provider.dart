import 'package:cableapp/data/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (!isSupabaseReady) {
    return Stream<AuthState?>.value(null);
  }
  return supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return isSupabaseReady ? supabase.auth.currentUser : null;
});

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(),
);

class AuthController {
  Future<void> signIn(String email, String password) async {
    if (!isSupabaseReady) {
      throw StateError('Supabase is not initialized yet.');
    }
    await supabase.auth.signInWithPassword(email: email, password: password);

    // Verify the signed-in user exists in the admins table.
    // Filter by current user ID to avoid maybeSingle() throwing
    // when multiple admin rows exist.
    // If not found, sign them out immediately with a clear error message.
    final userId = supabase.auth.currentUser?.id;
    final isAdmin = userId == null
        ? null
        : await supabase
              .from('admins')
              .select('id')
              .eq('id', userId)
              .maybeSingle();
    if (isAdmin == null) {
      await supabase.auth.signOut();
      throw Exception(
        'Your account is not authorised as an admin. '
        'Please contact your system administrator.',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    if (!isSupabaseReady) {
      throw StateError('Supabase is not initialized yet.');
    }
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    if (!isSupabaseReady) {
      return;
    }
    await supabase.auth.signOut();
  }
}
