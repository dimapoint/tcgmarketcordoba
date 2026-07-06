import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/api_provider.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/core/onboarding/onboarding_provider.dart';
import 'package:tcgmarketcordoba/core/onboarding/onboarding_store.dart';
import 'package:tcgmarketcordoba/core/router/router.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';
import 'package:tcgmarketcordoba/features/onboarding/onboarding_content.dart';

Map<String, dynamic> _authBody(String at, String rt) => {
      'access_token': at,
      'refresh_token': rt,
      'user': {'id': 'u1', 'email': 'a@b.com'},
    };

final _sessionPrefs = {
  'auth.access_token': 'at1',
  'auth.refresh_token': 'rt1',
  'auth.user_id': 'u1',
  'auth.email': 'a@b.com',
  'onboarding.last_seen_version': kOnboardingLatestVersion,
};

MockClient _mockApi() => MockClient((req) async {
      if (req.url.path == '/auth/signin') {
        return http.Response(jsonEncode(_authBody('at1', 'rt1')), 200);
      }
      return http.Response(jsonEncode([]), 200);
    });

Future<ApiClient> _apiClient() async {
  final prefs = await SharedPreferences.getInstance();
  return ApiClient(
      baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: _mockApi());
}

Future<OnboardingStore> _onboardingStore() async {
  return OnboardingStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authSessionProvider returns null session when logged out', () async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    final session = await container.read(authSessionProvider.future);
    expect(session, isNull);
  });

  group('computeRedirect', () {
    test('deslogueado en ruta protegida -> sign-in con from', () {
      final r = computeRedirect(
        loggedIn: false,
        hasSeenOnboarding: true,
        uri: Uri.parse('/post'),
        matchedLocation: '/post',
      );
      final uri = Uri.parse(r!);
      expect(uri.path, '/sign-in');
      expect(uri.queryParameters['from'], '/post');
    });

    test('deslogueado en /wanted/new?q= preserva la query en from', () {
      final r = computeRedirect(
        loggedIn: false,
        hasSeenOnboarding: true,
        uri: Uri.parse('/wanted/new?q=jinx'),
        matchedLocation: '/wanted/new',
      );
      final uri = Uri.parse(r!);
      expect(uri.path, '/sign-in');
      expect(uri.queryParameters['from'], '/wanted/new?q=jinx');

      // Y al volver del sign-in, el from vuelve intacto con la query.
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri(
              path: '/sign-in',
              queryParameters: {'from': '/wanted/new?q=jinx'}),
          matchedLocation: '/sign-in',
        ),
        '/wanted/new?q=jinx',
      );
    });

    test('deslogueado en rutas públicas -> null', () {
      for (final loc in ['/', '/listings/abc', '/sign-in', '/sign-up']) {
        expect(
          computeRedirect(
            loggedIn: false,
            hasSeenOnboarding: true,
            uri: Uri.parse(loc),
            matchedLocation: loc,
          ),
          isNull,
          reason: loc,
        );
      }
    });

    test('logueado en sign-in con from -> vuelve a from', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri.parse('/sign-in?from=%2Fpost'),
          matchedLocation: '/sign-in',
        ),
        '/post',
      );
    });

    test('logueado en sign-in sin from -> home', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri.parse('/sign-in'),
          matchedLocation: '/sign-in',
        ),
        '/',
      );
    });

    test('logueado en sign-up con from -> vuelve a from', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri.parse('/sign-up?from=%2Fmy-listings'),
          matchedLocation: '/sign-up',
        ),
        '/my-listings',
      );
    });

    test('logueado en ruta protegida -> null', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri.parse('/post'),
          matchedLocation: '/post',
        ),
        isNull,
      );
    });

    test('from inseguro se descarta', () {
      for (final from in ['https://evil.com', '//evil.com', '/sign-in']) {
        expect(
          computeRedirect(
            loggedIn: true,
            hasSeenOnboarding: true,
            uri: Uri(path: '/sign-in', queryParameters: {'from': from}),
            matchedLocation: '/sign-in',
          ),
          '/',
          reason: from,
        );
      }
    });

    test('logueado sin ver onboarding en home -> /onboarding', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: false,
          uri: Uri.parse('/'),
          matchedLocation: '/',
        ),
        '/onboarding',
      );
    });

    test('logueado sin ver onboarding en ruta protegida -> /onboarding', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: false,
          uri: Uri.parse('/post'),
          matchedLocation: '/post',
        ),
        '/onboarding',
      );
    });

    test('logueado sin ver onboarding, ya en /onboarding -> null (sin loop)',
        () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: false,
          uri: Uri.parse('/onboarding'),
          matchedLocation: '/onboarding',
        ),
        isNull,
      );
    });

    test('logueado y ya vio el onboarding, en /onboarding -> home', () {
      expect(
        computeRedirect(
          loggedIn: true,
          hasSeenOnboarding: true,
          uri: Uri.parse('/onboarding'),
          matchedLocation: '/onboarding',
        ),
        '/',
      );
    });

    test('deslogueado en /onboarding -> home', () {
      expect(
        computeRedirect(
          loggedIn: false,
          hasSeenOnboarding: false,
          uri: Uri.parse('/onboarding'),
          matchedLocation: '/onboarding',
        ),
        '/',
      );
    });
  });

  group('routerProvider', () {
    testWidgets('el router es estable ante cambios de sesión',
        (tester) async {
      SharedPreferences.setMockInitialValues(Map.of(_sessionPrefs));
      final api = await _apiClient();
      final onboarding = await _onboardingStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          onboardingStoreProvider.overrideWithValue(onboarding),
        ],
      );
      addTearDown(container.dispose);

      final router1 = container.read(routerProvider);
      await api.signOut();
      await tester.pump();
      final router2 = container.read(routerProvider);

      expect(identical(router1, router2), isTrue);
    });

    testWidgets('deslogueado: /post redirige a sign-in y el login vuelve a /post',
        (tester) async {
      // Onboarding ya visto: este test cubre el flujo de sign-in + from,
      // no la interacción con el onboarding (cubierta en un test aparte).
      SharedPreferences.setMockInitialValues(
          {'onboarding.last_seen_version': kOnboardingLatestVersion});
      final api = await _apiClient();
      final onboarding = await _onboardingStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          onboardingStoreProvider.overrideWithValue(onboarding),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/post');
      await tester.pumpAndSettle();
      final atSignIn = router.routerDelegate.currentConfiguration.uri;
      expect(atSignIn.path, '/sign-in');
      expect(atSignIn.queryParameters['from'], '/post');

      await api.signIn(email: 'a@b.com', password: 'password1');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/post',
      );
    });

    testWidgets('sesión persistida: entra directo a /post sin rebote',
        (tester) async {
      SharedPreferences.setMockInitialValues(Map.of(_sessionPrefs));
      final api = await _apiClient();
      final onboarding = await _onboardingStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          onboardingStoreProvider.overrideWithValue(onboarding),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/post');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/post',
      );
    });

    testWidgets('signOut en ruta protegida expulsa a sign-in',
        (tester) async {
      SharedPreferences.setMockInitialValues(Map.of(_sessionPrefs));
      final api = await _apiClient();
      final onboarding = await _onboardingStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          onboardingStoreProvider.overrideWithValue(onboarding),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      router.go('/post');
      await tester.pumpAndSettle();

      await api.signOut();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/sign-in',
      );
    });

    testWidgets(
        'sesión nueva sin onboarding visto: /post lleva primero a /onboarding',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ..._sessionPrefs,
        'onboarding.last_seen_version': 0,
      });
      final api = await _apiClient();
      final onboarding = await _onboardingStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          onboardingStoreProvider.overrideWithValue(onboarding),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/post');
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/onboarding',
      );
    });
  });
}
