import 'package:cableapp/app.dart';
import 'package:cableapp/data/supabase_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSupabase();
  runApp(const ProviderScope(child: CableCareAdminApp()));
}
