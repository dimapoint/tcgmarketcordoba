import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/features/auth/google/google_sign_in_section.dart';

Widget _app({String? clientId}) => ProviderScope(
      overrides: [googleClientIdProvider.overrideWithValue(clientId)],
      child: const MaterialApp(
        home: Scaffold(body: GoogleSignInSection()),
      ),
    );

void main() {
  testWidgets('se oculta si GOOGLE_CLIENT_ID no está configurado',
      (tester) async {
    await tester.pumpWidget(_app(clientId: null));
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('muestra el botón cuando hay client id', (tester) async {
    await tester.pumpWidget(_app(clientId: 'cid.apps.googleusercontent.com'));
    await tester.pump();
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
