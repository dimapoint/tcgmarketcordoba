import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/onboarding/onboarding_provider.dart';
import 'package:tcgmarketcordoba/core/onboarding/onboarding_store.dart';
import 'package:tcgmarketcordoba/features/onboarding/onboarding_content.dart';
import 'package:tcgmarketcordoba/features/onboarding/screens/onboarding_screen.dart';

const _testSlides = [
  OnboardingSlide(icon: Icons.star, title: 'Uno', body: 'Primero', version: 1),
  OnboardingSlide(icon: Icons.star, title: 'Dos', body: 'Segundo', version: 1),
];

Future<OnboardingStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return OnboardingStore(await SharedPreferences.getInstance());
}

Widget _harness(OnboardingStore store, List<OnboardingSlide> slides) {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (c, s) => OnboardingScreen(slides: slides),
      ),
      GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('Home'))),
    ],
  );
  return ProviderScope(
    overrides: [onboardingStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usuario nuevo ve los slides reales en orden', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_harness(store, kOnboardingSlides));
    await tester.pumpAndSettle();

    expect(find.text(kOnboardingSlides[0].title), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('Saltar marca visto con la versión más alta y navega a /',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_harness(store, _testSlides));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();

    expect(store.lastSeenVersion(), 1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('llegar hasta Comenzar marca visto y navega a /', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_harness(store, _testSlides));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Dos'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(store.lastSeenVersion(), 1);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
      'solo se muestra el slide nuevo cuando ya vio una versión anterior',
      (tester) async {
    final store = await _store();
    await store.markSeen(1);
    final slides = [
      ..._testSlides,
      const OnboardingSlide(
        icon: Icons.star,
        title: 'Nueva feature',
        body: 'Recién agregada',
        version: 2,
      ),
    ];
    await tester.pumpWidget(_harness(store, slides));
    await tester.pumpAndSettle();

    expect(find.text('Nueva feature'), findsOneWidget);
    expect(find.text('Uno'), findsNothing);
    expect(find.text('Saltar'), findsNothing);
    expect(find.text('Comenzar'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(store.lastSeenVersion(), 2);
  });
}
