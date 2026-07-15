import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/core/api/session.dart';
import 'package:tcgmarketcordoba/features/admin/admin_models.dart';
import 'package:tcgmarketcordoba/features/admin/admin_repository.dart';
import 'package:tcgmarketcordoba/features/admin/screens/admin_screen.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

class _FakeAdminRepository implements AdminRepository {
  final listingCalls = <(String, String)>[];
  final buyOrderCalls = <(String, String)>[];
  var syncStarts = 0;

  @override
  Future<List<FeedbackItem>> fetchFeedback() async => [
        FeedbackItem(
          id: 'f1',
          username: 'reporter',
          category: 'bug',
          message: 'algo se rompió',
          createdAt: DateTime.utc(2026, 7, 15),
        ),
      ];

  @override
  Future<AdminStats> fetchStats() async => const AdminStats(
        users: 10,
        activeListings: 5,
        activeBuyOrders: 3,
        newUsers7d: 2,
        newListings7d: 1,
        newBuyOrders7d: 4,
      );

  @override
  Future<List<Listing>> fetchListings(
          {String status = '', String query = ''}) async =>
      [
        Listing.fromJson({
          'id': 'l1',
          'seller_id': 'u1',
          'card_name': 'Jinx',
          'set_name': 'Origins',
          'is_foil': false,
          'condition': 'NM',
          'price': 1000.0,
          'description': null,
          'status': 'active',
          'seller_username': 'vendedor',
          'seller_city': 'Córdoba',
          'photos': <dynamic>[],
          'created_at': '2026-07-08T00:00:00Z',
          'card_image_url': null,
        }),
      ];

  @override
  Future<void> setListingStatus(String id, String status) async {
    listingCalls.add((id, status));
  }

  @override
  Future<List<WantedOrder>> fetchBuyOrders(
          {String status = '', String query = ''}) async =>
      [
        WantedOrder.fromJson({
          'id': 'b1',
          'buyer_id': 'u2',
          'card_name': 'Viktor',
          'set_name': 'Origins',
          'is_foil': false,
          'min_condition': null,
          'max_price': 500.0,
          'quantity': 1,
          'description': null,
          'status': 'removed',
          'buyer_username': 'comprador',
          'buyer_city': 'Córdoba',
          'created_at': '2026-07-08T00:00:00Z',
        }),
      ];

  @override
  Future<void> setBuyOrderStatus(String id, String status) async {
    buyOrderCalls.add((id, status));
  }

  @override
  Future<void> startSync() async {
    syncStarts++;
  }

  @override
  Future<SyncStatus> fetchSyncStatus() async =>
      const SyncStatus(status: 'idle');
}

AuthSession _session({required bool isAdmin}) => AuthSession(
      accessToken: 'at',
      refreshToken: 'rt',
      user: AuthUser(id: 'u1', email: 'a@b.com', isAdmin: isAdmin),
    );

(ProviderContainer, Widget, _FakeAdminRepository) _harness(
    {bool isAdmin = true}) {
  final repo = _FakeAdminRepository();
  final container = ProviderContainer(overrides: [
    adminRepositoryProvider.overrideWithValue(repo),
    authSessionProvider.overrideWith(
        (ref) => Stream.value(_session(isAdmin: isAdmin))),
  ]);
  final widget = UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: AdminScreen()),
  );
  return (container, widget, repo);
}

void main() {
  testWidgets('muestra stats y dispara el sync', (tester) async {
    final (container, widget, repo) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget); // usuarios
    expect(find.text('5'), findsOneWidget); // listings activas
    expect(find.text('3'), findsOneWidget); // buscados activos

    await tester.dragUntilVisible(
      find.text('Sincronizar cartas'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sincronizar cartas'));
    await tester.pumpAndSettle();
    expect(repo.syncStarts, 1);
  });

  testWidgets('modera una publicación: Quitar llama al repo', (tester) async {
    final (container, widget, repo) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publicaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Jinx'), findsOneWidget);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();

    // Quitar pide confirmación; cancelar no llama al repo.
    expect(find.text('Confirmar acción'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.listingCalls, isEmpty);

    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
    await tester.pumpAndSettle();
    expect(repo.listingCalls, [('l1', 'removed')]);
  });

  testWidgets('restaura un buscado eliminado', (tester) async {
    final (container, widget, repo) = _harness();
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscados'));
    await tester.pumpAndSettle();

    expect(find.text('Viktor'), findsOneWidget);
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();
    expect(repo.buyOrderCalls, [('b1', 'active')]);
  });

  testWidgets('no-admin ve el mensaje de acceso restringido', (tester) async {
    final (container, widget, _) = _harness(isAdmin: false);
    addTearDown(container.dispose);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Solo para administradores'), findsOneWidget);
    expect(find.text('Sincronizar cartas'), findsNothing);
  });
}
