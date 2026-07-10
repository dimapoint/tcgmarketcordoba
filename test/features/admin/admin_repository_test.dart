import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/admin/admin_repository.dart';

Map<String, dynamic> _listingJson() => {
      'id': 'l1',
      'seller_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'condition': 'NM',
      'price': 1000.0,
      'description': null,
      'status': 'removed',
      'seller_username': 'vendedor',
      'seller_city': 'Córdoba',
      'photos': <dynamic>[],
      'created_at': '2026-07-08T00:00:00Z',
      'card_image_url': '/card-images/abc.png',
    };

Map<String, dynamic> _buyOrderJson() => {
      'id': 'b1',
      'buyer_id': 'u1',
      'card_name': 'Kha\'Zix',
      'set_name': 'Origins',
      'is_foil': false,
      'min_condition': null,
      'max_price': 500.0,
      'quantity': 1,
      'description': null,
      'status': 'active',
      'buyer_username': 'comprador',
      'buyer_city': 'Córdoba',
      'created_at': '2026-07-08T00:00:00Z',
    };

Future<ApiAdminRepository> _repo(MockClient mock) async {
  SharedPreferences.setMockInitialValues({
    'auth.access_token': 'tok',
    'auth.refresh_token': 'rt',
    'auth.user_id': 'admin-1',
    'auth.email': 'admin@x.com',
    'auth.is_admin': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ApiAdminRepository(ApiClient(
      baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchStats pega a /admin/stats con auth y parsea contadores',
      () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/admin/stats');
      expect(req.headers['Authorization'], 'Bearer tok');
      return http.Response(
          jsonEncode({
            'users': 10,
            'active_listings': 5,
            'active_buy_orders': 3,
            'new_users_7d': 2,
            'new_listings_7d': 1,
            'new_buy_orders_7d': 4,
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final stats = await (await _repo(mock)).fetchStats();
    expect(stats.users, 10);
    expect(stats.activeListings, 5);
    expect(stats.activeBuyOrders, 3);
    expect(stats.newUsers7d, 2);
    expect(stats.newListings7d, 1);
    expect(stats.newBuyOrders7d, 4);
  });

  test('fetchListings manda filtros y absolutiza card_image_url', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/admin/listings');
      expect(req.url.queryParameters, {'status': 'removed', 'q': 'jinx'});
      expect(req.headers['Authorization'], 'Bearer tok');
      return http.Response(jsonEncode([_listingJson()]), 200,
          headers: {'content-type': 'application/json'});
    });
    final items = await (await _repo(mock))
        .fetchListings(status: 'removed', query: 'jinx');
    expect(items, hasLength(1));
    expect(items.first.status, 'removed');
    expect(items.first.cardImageUrl, 'http://x/card-images/abc.png');
  });

  test('fetchListings sin filtros no manda query params', () async {
    final mock = MockClient((req) async {
      expect(req.url.queryParameters, isEmpty);
      return http.Response(jsonEncode([]), 200,
          headers: {'content-type': 'application/json'});
    });
    await (await _repo(mock)).fetchListings();
  });

  test('setListingStatus patchea el estado', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'PATCH');
      expect(req.url.path, '/admin/listings/l1');
      expect(jsonDecode(req.body), {'status': 'removed'});
      return http.Response('', 204);
    });
    await (await _repo(mock)).setListingStatus('l1', 'removed');
  });

  test('fetchBuyOrders manda filtros y parsea', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/admin/buy-orders');
      expect(req.url.queryParameters, {'status': 'active', 'q': 'kha'});
      return http.Response(jsonEncode([_buyOrderJson()]), 200,
          headers: {'content-type': 'application/json'});
    });
    final items =
        await (await _repo(mock)).fetchBuyOrders(status: 'active', query: 'kha');
    expect(items, hasLength(1));
    expect(items.first.buyerUsername, 'comprador');
  });

  test('setBuyOrderStatus patchea el estado', () async {
    final mock = MockClient((req) async {
      expect(req.method, 'PATCH');
      expect(req.url.path, '/admin/buy-orders/b1');
      expect(jsonDecode(req.body), {'status': 'active'});
      return http.Response('', 204);
    });
    await (await _repo(mock)).setBuyOrderStatus('b1', 'active');
  });

  test('startSync postea y fetchSyncStatus parsea el estado', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/admin/sync-cards');
      if (req.method == 'POST') {
        return http.Response(
            jsonEncode({'status': 'running', 'started_at': '2026-07-10T12:00:00Z'}),
            202,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
          jsonEncode({
            'status': 'ok',
            'started_at': '2026-07-10T12:00:00Z',
            'finished_at': '2026-07-10T12:05:00Z',
            'summary': {'sets': 8, 'cards': 964, 'printings': 964, 'new_cards': 0},
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final repo = await _repo(mock);
    await repo.startSync();
    final status = await repo.fetchSyncStatus();
    expect(status.status, 'ok');
    expect(status.summary?.cards, 964);
    expect(status.summary?.sets, 8);
    expect(status.finishedAt, isNotNull);
    expect(status.error, isNull);
  });
}
