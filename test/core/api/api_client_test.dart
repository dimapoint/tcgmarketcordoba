import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/api/api_client.dart';
import 'package:tcgmarketcordoba/core/api/token_store.dart';

Map<String, dynamic> _authBody(String at, String rt) => {
      'access_token': at,
      'refresh_token': rt,
      'user': {'id': 'u1', 'email': 'a@b.com'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signIn stores session and persists tokens', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      expect(req.url.path, '/auth/signin');
      return http.Response(jsonEncode(_authBody('at1', 'rt1')), 200,
          headers: {'content-type': 'application/json'});
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await api.signIn(email: 'a@b.com', password: 'password1');

    expect(api.session?.user.id, 'u1');
    expect(TokenStore(prefs).load()?.accessToken, 'at1');
  });

  test('401 triggers refresh and retries once', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'viejo',
      'auth.refresh_token': 'rt-viejo',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    var calls = <String>[];
    final mock = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path == '/auth/refresh') {
        return http.Response(jsonEncode(_authBody('at-nuevo', 'rt-nuevo')), 200);
      }
      final token = req.headers['Authorization'];
      if (token == 'Bearer viejo') {
        return http.Response(jsonEncode({'error': 'token inválido'}), 401);
      }
      return http.Response(jsonEncode([]), 200);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    final result = await api.get('/me/listings', auth: true);

    expect(result, isA<List>());
    expect(calls, ['/me/listings', '/auth/refresh', '/me/listings']);
    expect(api.session?.accessToken, 'at-nuevo');
  });

  test('failed refresh clears session', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'viejo',
      'auth.refresh_token': 'rt-vencido',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      if (req.url.path == '/auth/refresh') {
        return http.Response(jsonEncode({'error': 'refresh token inválido'}), 401);
      }
      return http.Response(jsonEncode({'error': 'token inválido'}), 401);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await expectLater(api.get('/me/listings', auth: true),
        throwsA(isA<ApiException>()));
    expect(api.session, isNull);
  });
}
