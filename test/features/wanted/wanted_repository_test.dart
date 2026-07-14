import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/wanted/wanted_repository.dart';

Map<String, dynamic> _order({String? cardImageUrl}) => {
      'id': 'b1',
      'buyer_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'min_condition': null,
      'max_price': 1000.0,
      'quantity': 1,
      'description': null,
      'status': 'active',
      'buyer_username': 'comprador',
      'buyer_city': 'Córdoba',
      'created_at': '2026-07-08T00:00:00Z',
      'card_image_url': cardImageUrl,
    };

Future<ApiWantedRepository> _repo(String? cardImageUrl) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final mock = MockClient((req) async => http.Response(
        jsonEncode({'data': [_order(cardImageUrl: cardImageUrl)], 'next_cursor': null}),
        200,
        headers: {'content-type': 'application/json'},
      ));
  final api = ApiClient(
      baseUrl: 'http://api.local', tokens: TokenStore(prefs), httpClient: mock);
  return ApiWantedRepository(api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('card_image_url relativa se resuelve contra baseUrl', () async {
    final repo = await _repo('/card-images/abc.png');
    final result = await repo.fetchActive();
    expect(result.single.cardImageUrl, 'http://api.local/card-images/abc.png');
  });

  test('card_image_url null queda null', () async {
    final repo = await _repo(null);
    final result = await repo.fetchActive();
    expect(result.single.cardImageUrl, isNull);
  });
}
