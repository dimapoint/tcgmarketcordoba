import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';
import 'package:tcgmarketcordoba/features/post_listing/photo_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upload manda bytes + display_order al endpoint del listing', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'at1',
      'auth.refresh_token': 'rt1',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    String? path;
    String? body;
    final mock = MockClient((req) async {
      path = req.url.path;
      body = utf8.decode(req.bodyBytes, allowMalformed: true);
      return http.Response(jsonEncode({'url': 'http://x/p1.jpg'}), 200);
    });
    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);

    final repo = ApiPhotoRepository(api);
    final url = await repo.upload(
      listingId: 'l1',
      bytes: utf8.encode('pixeles'),
      filename: 'carta.jpg',
      order: 2,
    );

    expect(url, 'http://x/p1.jpg');
    expect(path, '/listings/l1/photos');
    expect(body, contains('pixeles'));
    expect(body, contains('filename="carta.jpg"'));
    expect(body, contains('display_order'));
  });
}
