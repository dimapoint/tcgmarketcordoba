import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/profile/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchCities parses the /cities list', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      expect(req.url.path, '/cities');
      return http.Response(
          jsonEncode([
            {'id': 'c1', 'name': 'Córdoba Capital'},
            {'id': 'c2', 'name': 'Villa María'},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final repo = ApiProfileRepository(ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock));
    final cities = await repo.fetchCities();

    expect(cities, hasLength(2));
    expect(cities.first.id, 'c1');
    expect(cities.first.name, 'Córdoba Capital');
  });
}
