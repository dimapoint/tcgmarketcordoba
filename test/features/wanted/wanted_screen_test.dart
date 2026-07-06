import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/features/wanted/screens/wanted_screen.dart';
import 'package:tcgmarketcordoba/features/wanted/wanted_provider.dart';
import 'package:tcgmarketcordoba/features/wanted/wanted_repository.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

WantedOrder _order() => WantedOrder(
      id: 'w-1',
      buyerId: 'b-1',
      cardName: 'Viktor',
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
  Future<WantedOrder> fetchById(String id) async => orders.first;
}

(ProviderContainer, Widget) _harness({required List<WantedOrder> orders}) {
  final container = ProviderContainer(overrides: [
    wantedRepositoryProvider.overrideWithValue(_FakeWantedRepository(orders)),
  ]);
  final router = GoRouter(
    initialLocation: '/wanted',
    routes: [
      GoRoute(path: '/wanted', builder: (c, s) => const WantedScreen()),
      GoRoute(
        path: '/wanted/new',
        builder: (c, s) => Scaffold(
          body: Text('NEW q=${s.uri.queryParameters['q'] ?? ''}'),
        ),
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
  testWidgets('FAB "Publicar búsqueda" visible con tablero poblado y navega '
      'a /wanted/new', (tester) async {
    final (container, widget) = _harness(orders: [_order()]);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Viktor'), findsOneWidget);
    final fab = find.widgetWithText(FloatingActionButton, 'Publicar búsqueda');
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('NEW q='), findsOneWidget);
  });

  testWidgets('empty state con query ofrece publicar búsqueda prefillada',
      (tester) async {
    final (container, widget) = _harness(orders: [_order()]);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    container.read(wantedSearchQueryProvider.notifier).state = 'jinx';
    await tester.pumpAndSettle();

    expect(find.text('Nadie está buscando "jinx" todavía'), findsOneWidget);
    final cta = find.text('Publicar búsqueda de "jinx"');
    expect(cta, findsOneWidget);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('NEW q=jinx'), findsOneWidget);
  });

  testWidgets('empty state sin query mantiene el mensaje genérico',
      (tester) async {
    final (container, widget) = _harness(orders: []);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(
        find.text('Todavía nadie publicó qué está buscando'), findsOneWidget);
    expect(find.text('Publicar una búsqueda'), findsOneWidget);
  });
}
