import 'package:cableapp/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CableCare Admin shows login when signed out', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pump();

    expect(find.text('CableCare Admin'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });
}
