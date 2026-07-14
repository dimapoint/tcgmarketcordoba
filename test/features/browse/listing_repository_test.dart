import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/browse/listing_repository.dart';

Map<String, dynamic> _listing({String? cardImageUrl}) => {
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
      'card_image_url': cardImageUrl,
    };

Future<ApiListingRepository> _repo(String? cardImageUrl) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final mock = MockClient((req) async {
    final body = req.url.path == '/listings/l1'
        ? jsonEncode(_listing(cardImageUrl: cardImageUrl))
        : jsonEncode({'data': [_listing(cardImageUrl: cardImageUrl)], 'next_cursor': null});
    return http.Response(body, 200,
        headers: {'content-type': 'application/json'});
  });
  final api = ApiClient(
      baseUrl: 'http://api.local', tokens: TokenStore(prefs), httpClient: mock);
  return ApiListingRepository(api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('card_image_url relativa se resuelve contra baseUrl en fetchActive',
      () async {
    final repo = await _repo('/card-images/abc.png');
    final result = await repo.fetchActive();
    expect(result.single.cardImageUrl, 'http://api.local/card-images/abc.png');
  });

  test('card_image_url relativa se resuelve contra baseUrl en fetchById',
      () async {
    final repo = await _repo('/card-images/abc.png');
    final result = await repo.fetchById('l1');
    expect(result.cardImageUrl, 'http://api.local/card-images/abc.png');
  });

  test('card_image_url null queda null', () async {
    final repo = await _repo(null);
    final result = await repo.fetchActive();
    expect(result.single.cardImageUrl, isNull);
  });
}
