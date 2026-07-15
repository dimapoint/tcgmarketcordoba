import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/features/seller/screens/seller_screen.dart';
import 'package:tcgmarketcordoba/features/seller/seller_repository.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';
import 'package:tcgmarketcordoba/shared/models/seller_page.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

Listing _listing() => Listing(
      id: 'l-1',
      sellerId: 'u-1',
      cardPrintingId: 'cp-1',
      cardName: 'Jinx',
      setName: 'Origins',
      isFoil: false,
      condition: 'NM',
      price: 15000,
      status: 'active',
      sellerUsername: 'dima',
      sellerCity: 'Córdoba',
      photos: const [],
      createdAt: DateTime.parse('2026-07-01T10:00:00Z'),
    );

WantedOrder _order() => WantedOrder(
      id: 'w-1',
      buyerId: 'u-1',
      cardName: 'Viktor',
      setName: 'Origins',
      isFoil: false,
      maxPrice: 5000,
      quantity: 1,
      status: 'active',
      buyerUsername: 'dima',
      buyerCity: 'Córdoba',
      createdAt: DateTime.parse('2026-07-01T10:00:00Z'),
    );

class _FakeSellerRepository implements SellerRepository {
  final SellerPage page;
  _FakeSellerRepository(this.page);

  @override
  Future<SellerPage> fetch(String username) async => page;
}

(ProviderContainer, Widget) _harness(SellerPage page) {
  final container = ProviderContainer(overrides: [
    sellerRepositoryProvider.overrideWithValue(_FakeSellerRepository(page)),
  ]);
  final router = GoRouter(
    initialLocation: '/u/dima',
    routes: [
      GoRoute(
        path: '/u/:username',
        builder: (c, s) => SellerScreen(username: s.pathParameters['username']!),
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
  testWidgets('muestra perfil y secciones Vende/Busca', (tester) async {
    final page = SellerPage(
      profile: const SellerProfile(username: 'dima', city: 'Córdoba'),
      listings: [_listing()],
      buyOrders: [_order()],
    );
    final (container, widget) = _harness(page);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('dima'), findsWidgets);
    expect(find.text('Córdoba'), findsOneWidget);
    expect(find.text('Vende'), findsOneWidget);
    expect(find.text('Jinx'), findsOneWidget);
    expect(find.text('Busca'), findsOneWidget);
    expect(find.text('Viktor'), findsOneWidget);
  });

  testWidgets('sin publicaciones muestra estado vacío', (tester) async {
    final page = SellerPage(
      profile: const SellerProfile(username: 'dima', city: 'Córdoba'),
      listings: const [],
      buyOrders: const [],
    );
    final (container, widget) = _harness(page);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Todavía no publicó nada'), findsOneWidget);
    expect(find.text('Vende'), findsNothing);
    expect(find.text('Busca'), findsNothing);
  });
}
