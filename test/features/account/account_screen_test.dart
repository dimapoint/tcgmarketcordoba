import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/core/api/session.dart';
import 'package:tcgmarketcordoba/features/account/screens/account_screen.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';
import 'package:tcgmarketcordoba/features/my_listings/my_listings_provider.dart';
import 'package:tcgmarketcordoba/features/profile/profile_provider.dart';
import 'package:tcgmarketcordoba/shared/models/profile.dart';

AuthSession _session() => AuthSession(
      accessToken: 'at',
      refreshToken: 'rt',
      user: AuthUser(id: 'u1', email: 'a@b.com', isAdmin: false),
    );

Widget _harness({String? initialTab}) {
  final container = ProviderContainer(overrides: [
    authSessionProvider.overrideWith((ref) => Stream.value(_session())),
    profileProvider.overrideWith(
        (ref) async => const Profile(id: 'u1', username: 'dima')),
    contactMethodsProvider.overrideWith((ref) async => []),
    myListingsProvider('active').overrideWith((ref) async => []),
    myListingsProvider('sold').overrideWith((ref) async => []),
  ]);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: AccountScreen(initialTab: initialTab),
    ),
  );
}

void main() {
  testWidgets('muestra los tabs Mis cartas y Perfil', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Mis cartas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('el tab Mis cartas muestra Activas/Vendidas por defecto',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Activas'), findsOneWidget);
    expect(find.text('Vendidas'), findsOneWidget);
  });

  testWidgets('tocar Perfil muestra Métodos de contacto', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Métodos de contacto'), findsOneWidget);
  });

  testWidgets('initialTab perfil abre directo en Perfil', (tester) async {
    await tester.pumpWidget(_harness(initialTab: 'perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Métodos de contacto'), findsOneWidget);
  });
}
