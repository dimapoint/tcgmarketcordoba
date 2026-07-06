import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/features/browse/listing_provider.dart';
import 'package:tcgmarketcordoba/features/browse/listing_repository.dart';
import 'package:tcgmarketcordoba/features/browse/screens/browse_screen.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

class _FakeListingRepository implements ListingRepository {
  @override
  Future<List<Listing>> fetchActive({String? query}) async => [];

  @override
  Future<Listing> fetchById(String id) => throw UnimplementedError();
}

(ProviderContainer, Widget) _harness() {
  final container = ProviderContainer(overrides: [
    listingRepositoryProvider.overrideWithValue(_FakeListingRepository()),
  ]);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const BrowseScreen()),
      GoRoute(
        path: '/wanted/new',
        builder: (c, s) => Scaffold(
          body: Text('NEW q=${s.uri.queryParameters['q'] ?? ''}'),
        ),
      ),
      GoRoute(
        path: '/post',
        builder: (c, s) => const Scaffold(body: Text('POST')),
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
  testWidgets('búsqueda sin resultados ofrece publicar una búsqueda prefillada',
      (tester) async {
    final (container, widget) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    container.read(searchQueryProvider.notifier).state = 'jinx';
    await tester.pumpAndSettle();

    expect(find.text('No hay publicaciones de "jinx"'), findsOneWidget);
    final cta = find.text('Publicar una búsqueda');
    expect(cta, findsOneWidget);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('NEW q=jinx'), findsOneWidget);
  });

  testWidgets('búsqueda sin resultados también ofrece venderla', (tester) async {
    final (container, widget) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    container.read(searchQueryProvider.notifier).state = 'jinx';
    await tester.pumpAndSettle();

    final secondary = find.text('Vendela vos');
    expect(secondary, findsOneWidget);

    await tester.tap(secondary);
    await tester.pumpAndSettle();
    expect(find.text('POST'), findsOneWidget);
  });

  testWidgets('sin query se mantiene el empty state original', (tester) async {
    final (container, widget) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay cartas publicadas'), findsOneWidget);
    expect(find.text('Publicá la primera'), findsOneWidget);
  });
}
