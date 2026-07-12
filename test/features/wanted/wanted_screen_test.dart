import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/core/api/session.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';
import 'package:tcgmarketcordoba/features/my_wanted/my_wanted_repository.dart';
import 'package:tcgmarketcordoba/features/wanted/screens/wanted_screen.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

WantedOrder _order({String? cardImageUrl}) => WantedOrder(
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
      cardImageUrl: cardImageUrl,
      createdAt: DateTime.parse('2026-07-01T10:00:00Z'),
    );

class _FakeMyWantedRepository implements MyWantedRepository {
  final List<WantedOrder> orders;
  _FakeMyWantedRepository(this.orders);

  @override
  Future<List<WantedOrder>> fetchMine(
          {required String buyerId, required String status}) async =>
      orders;

  @override
  Future<void> markFulfilled(String wantedOrderId) async {}

  @override
  Future<void> remove(String wantedOrderId) async {}
}

const _session = AuthSession(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: AuthUser(id: 'b-1', email: 'comprador@test.com'),
);

(ProviderContainer, Widget) _harness({
  List<WantedOrder> myOrders = const [],
  bool signedIn = false,
}) {
  final container = ProviderContainer(overrides: [
    myWantedRepositoryProvider
        .overrideWithValue(_FakeMyWantedRepository(myOrders)),
    authSessionProvider
        .overrideWith((ref) => Stream.value(signedIn ? _session : null)),
  ]);
  final router = GoRouter(
    initialLocation: '/wanted',
    routes: [
      GoRoute(path: '/wanted', builder: (c, s) => const WantedScreen()),
      GoRoute(
        path: '/wanted/new',
        builder: (c, s) => const Scaffold(body: Text('NEW')),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (c, s) => const Scaffold(body: Text('SIGN-IN')),
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
  testWidgets('sin sesión pide iniciar sesión y no muestra el FAB',
      (tester) async {
    final (container, widget) = _harness(signedIn: false);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Iniciá sesión para ver tus búsquedas'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('SIGN-IN'), findsOneWidget);
  });

  testWidgets('con sesión y sin búsquedas ofrece publicar la primera',
      (tester) async {
    final (container, widget) = _harness(signedIn: true, myOrders: []);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('No tenés búsquedas activas'), findsOneWidget);
    final cta = find.text('Publicar una búsqueda');
    expect(cta, findsOneWidget);

    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('FAB "Publicar búsqueda" navega a /wanted/new', (tester) async {
    final (container, widget) = _harness(signedIn: true, myOrders: [_order()]);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final fab = find.widgetWithText(FloatingActionButton, 'Publicar búsqueda');
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('muestra la imagen de catálogo de la carta', (tester) async {
    final (container, widget) = _harness(
      signedIn: true,
      myOrders: [
        _order(cardImageUrl: 'http://api.local/card-images/abc.png'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Viktor'), findsOneWidget);
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'http://api.local/card-images/abc.png?w=120');
  });
}
