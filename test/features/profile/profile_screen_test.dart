import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/core/api/session.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';
import 'package:tcgmarketcordoba/features/profile/profile_provider.dart';
import 'package:tcgmarketcordoba/features/profile/screens/profile_screen.dart';
import 'package:tcgmarketcordoba/shared/models/profile.dart';

AuthSession _session({required bool isAdmin}) => AuthSession(
      accessToken: 'at',
      refreshToken: 'rt',
      user: AuthUser(id: 'u1', email: 'a@b.com', isAdmin: isAdmin),
    );

(ProviderContainer, Widget) _harness({required bool isAdmin}) {
  final container = ProviderContainer(overrides: [
    authSessionProvider
        .overrideWith((ref) => Stream.value(_session(isAdmin: isAdmin))),
    profileProvider.overrideWith(
        (ref) async => const Profile(id: 'u1', username: 'dima')),
    contactMethodsProvider.overrideWith((ref) async => []),
  ]);
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(
        path: '/admin',
        builder: (c, s) => const Scaffold(body: Text('ADMIN')),
      ),
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
  return (container, widget);
}

void main() {
  testWidgets('admin ve el acceso al panel y navega', (tester) async {
    final (container, widget) = _harness(isAdmin: true);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final entry = find.text('Panel de administración');
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('no-admin no ve el acceso al panel', (tester) async {
    final (container, widget) = _harness(isAdmin: false);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Panel de administración'), findsNothing);
  });
}
