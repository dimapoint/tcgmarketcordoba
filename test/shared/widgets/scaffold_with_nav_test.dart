import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tcgmarketcordoba/features/matches/matches_provider.dart';
import 'package:tcgmarketcordoba/shared/widgets/scaffold_with_nav.dart';

Widget _app({required int unseen}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (c, s, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const Text('HOME')),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      unseenMatchesProvider.overrideWith((ref) => Future.value(unseen)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  // Sin red en tests: GoogleFonts (Wordmark) usa la fuente de fallback.
  GoogleFonts.config.allowRuntimeFetching = false;

  void mobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('móvil: badge con la cantidad de novedades en Busco',
      (tester) async {
    mobileSize(tester);
    await tester.pumpWidget(_app(unseen: 3));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(Badge), findsWidgets);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('móvil: 4 destinos, Mi cuenta unifica Mis Cartas y Perfil',
      (tester) async {
    mobileSize(tester);
    await tester.pumpWidget(_app(unseen: 0));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final label in ['Explorar', 'Busco', 'Publicar', 'Mi cuenta']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('móvil: sin novedades no hay badge', (tester) async {
    mobileSize(tester);
    await tester.pumpWidget(_app(unseen: 0));
    await tester.pumpAndSettle();

    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('wide: el header también muestra el badge', (tester) async {
    // Tamaño default del harness (800x600) >= mobileBreakpoint: header wide.
    await tester.pumpWidget(_app(unseen: 2));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });
}
