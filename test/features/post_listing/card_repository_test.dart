import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';

Map<String, dynamic> _printing({String? imageUrl}) => {
      'id': 'p1',
      'card_id': 'c1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'set_code': 'OGN',
      'card_number': '001',
      'is_foil': false,
      'image_url': imageUrl,
      'wanted_count': 0,
    };

Future<ApiCardRepository> _repo(dynamic imageUrl) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final mock = MockClient((req) async => http.Response(
        jsonEncode([_printing(imageUrl: imageUrl as String?)]),
        200,
        headers: {'content-type': 'application/json'},
      ));
  final api = ApiClient(
      baseUrl: 'http://api.local', tokens: TokenStore(prefs), httpClient: mock);
  return ApiCardRepository(api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image_url relativa se resuelve contra baseUrl', () async {
    final repo = await _repo('/card-images/abc.png');
    final result = await repo.search('jinx');
    expect(result.single.imageUrl, 'http://api.local/card-images/abc.png');
  });

  test('image_url absoluta queda igual', () async {
    final repo = await _repo('https://otro.cdn/x.png');
    final result = await repo.search('jinx');
    expect(result.single.imageUrl, 'https://otro.cdn/x.png');
  });

  test('image_url null queda null', () async {
    final repo = await _repo(null);
    final result = await repo.search('jinx');
    expect(result.single.imageUrl, isNull);
  });

  test('priceReference pega al endpoint y parsea la respuesta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    late Uri requested;
    final mock = MockClient((req) async {
      requested = req.url;
      return http.Response(
        jsonEncode({
          'market_usd': 15.26,
          'market_ars': 23000,
          'fx_rate': 1510,
          'is_foil': true,
          'local_active_count': 3,
          'local_min_price': 10000,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(
        baseUrl: 'http://api.local',
        tokens: TokenStore(prefs),
        httpClient: mock);
    final repo = ApiCardRepository(api);

    final ref = await repo.priceReference('cp-9');

    expect(requested.path, '/card-printings/cp-9/price-reference');
    expect(ref.marketUsd, 15.26);
    expect(ref.marketArs, 23000);
    expect(ref.localActiveCount, 3);
  });
}
