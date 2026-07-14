import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/core/api/paginated.dart';
import 'package:tcgmarketcordoba/features/browse/listing_provider.dart';
import 'package:tcgmarketcordoba/features/browse/listing_repository.dart';
import 'package:tcgmarketcordoba/features/browse/screens/browse_screen.dart';
import 'package:tcgmarketcordoba/features/wanted/wanted_repository.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

class _FakeListingRepository implements ListingRepository {
  @override
  Future<List<Listing>> fetchActive({String? query}) async => [];

  @override
  Future<PaginatedList<Listing>> fetchActivePage({String? query, String? cursor, int limit = 20}) async =>
      PaginatedList(data: await fetchActive(query: query), nextCursor: null);

  @override
  Future<Listing> fetchById(String id) => throw UnimplementedError();
}

WantedOrder _wantedOrder({String cardName = 'Viktor'}) => WantedOrder(
      id: 'w-1',
      buyerId: 'b-1',
      cardName: cardName,
      setName: 'Origins',
      isFoil: false,
      maxPrice: 5000,
      quantity: 1,
      status: 'active',
      buyerUsername: 'comprador',
      buyerCity: 'Córdoba',
      createdAt: DateTime.parse('2026-07-01T10:00:00Z'),
    );

class _FakeWantedRepository implements WantedRepository {
  final List<WantedOrder> orders;
  _FakeWantedRepository(this.orders);

  @override
  Future<List<WantedOrder>> fetchActive({String? query}) async {
    if (query == null || query.isEmpty) return orders;
    return orders
        .where((o) => o.cardName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<PaginatedList<WantedOrder>> fetchActivePage({String? query, String? cursor, int limit = 20}) async =>
      PaginatedList(data: await fetchActive(query: query), nextCursor: null);

  @override
  Future<WantedOrder> fetchById(String id) async => orders.first;
}

(ProviderContainer, Widget) _harness({List<WantedOrder> wantedOrders = const []}) {
  final container = ProviderContainer(overrides: [
    listingRepositoryProvider.overrideWithValue(_FakeListingRepository()),
    wantedRepositoryProvider.overrideWithValue(_FakeWantedRepository(wantedOrders)),
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

  testWidgets('toggle "Se busca" muestra el tablero de demanda de otros',
      (tester) async {
    final (container, widget) =
        _harness(wantedOrders: [_wantedOrder(cardName: 'Kha\'Zix')]);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se busca'));
    await tester.pumpAndSettle();

    expect(find.text('Kha\'Zix'), findsOneWidget);
  });

  testWidgets(
      'tablero "Se busca": empty state con query ofrece publicar búsqueda '
      'prefillada', (tester) async {
    final (container, widget) =
        _harness(wantedOrders: [_wantedOrder(cardName: 'Kha\'Zix')]);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se busca'));
    await tester.pumpAndSettle();
    container.read(searchQueryProvider.notifier).state = 'jinx';
    await tester.pumpAndSettle();

    expect(find.text('Nadie está buscando "jinx" todavía'), findsOneWidget);
    final cta = find.text('Publicar búsqueda de "jinx"');
    expect(cta, findsOneWidget);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('NEW q=jinx'), findsOneWidget);
  });

  testWidgets(
      'tablero "Se busca": empty state sin query mantiene el mensaje '
      'genérico', (tester) async {
    final (container, widget) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se busca'));
    await tester.pumpAndSettle();

    expect(
        find.text('Todavía nadie publicó qué está buscando'), findsOneWidget);
    expect(find.text('Publicar una búsqueda'), findsOneWidget);
  });
}
