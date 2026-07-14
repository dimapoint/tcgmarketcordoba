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

  test('signIn parsea is_admin y lo persiste en TokenStore', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      final body = {
        'access_token': 'at1',
        'refresh_token': 'rt1',
        'user': {'id': 'u1', 'email': 'a@b.com', 'is_admin': true},
      };
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await api.signIn(email: 'a@b.com', password: 'password1');

    expect(api.session?.user.isAdmin, isTrue);
    expect(TokenStore(prefs).load()?.user.isAdmin, isTrue);
  });

  test('sesión sin is_admin (backend viejo o prefs pre-deploy) => false',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'at1',
      'auth.refresh_token': 'rt1',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(TokenStore(prefs).load()?.user.isAdmin, isFalse);

    final mock = MockClient((req) async => http.Response(
        jsonEncode(_authBody('at2', 'rt2')), 200,
        headers: {'content-type': 'application/json'}));
    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await api.signIn(email: 'a@b.com', password: 'password1');
    expect(api.session?.user.isAdmin, isFalse);
  });

  test('signInWithGoogle posts id_token and stores session', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final mock = MockClient((req) async {
      expect(req.url.path, '/auth/google');
      expect(jsonDecode(req.body), {'id_token': 'google-tok'});
      return http.Response(jsonEncode(_authBody('at1', 'rt1')), 200,
          headers: {'content-type': 'application/json'});
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    await api.signInWithGoogle(idToken: 'google-tok');

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

  test('concurrent 401s share a single refresh (token de un solo uso)',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'viejo',
      'auth.refresh_token': 'rt-viejo',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    var refreshCalls = 0;
    final mock = MockClient((req) async {
      if (req.url.path == '/auth/refresh') {
        refreshCalls++;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        // Simula el backend: el refresh token se consume en el primer uso.
        if (refreshCalls > 1 || body['refresh_token'] != 'rt-viejo') {
          return http.Response(
              jsonEncode({'error': 'refresh token inválido'}), 401);
        }
        return http.Response(jsonEncode(_authBody('at-nuevo', 'rt-nuevo')), 200);
      }
      if (req.headers['Authorization'] == 'Bearer viejo') {
        return http.Response(jsonEncode({'error': 'token inválido'}), 401);
      }
      return http.Response(jsonEncode([]), 200);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    final results = await Future.wait([
      api.get('/me/listings', auth: true),
      api.get('/me/contact-methods', auth: true),
    ]);

    expect(refreshCalls, 1);
    expect(results, everyElement(isA<List>()));
    expect(api.session, isNotNull);
    expect(api.session?.accessToken, 'at-nuevo');
  });

  test('uploadFile manda los bytes como multipart (sin dart:io)', () async {
    SharedPreferences.setMockInitialValues({
      'auth.access_token': 'at1',
      'auth.refresh_token': 'rt1',
      'auth.user_id': 'u1',
      'auth.email': 'a@b.com',
    });
    final prefs = await SharedPreferences.getInstance();
    List<int>? receivedBody;
    String? contentType;
    final mock = MockClient((req) async {
      receivedBody = req.bodyBytes;
      contentType = req.headers['content-type'];
      return http.Response(jsonEncode({'url': 'http://x/foto.jpg'}), 200);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    final result = await api.uploadFile(
      '/photos',
      bytes: utf8.encode('contenido-jpg'),
      filename: 'foto.jpg',
      fields: {'display_order': '2'},
    );

    expect(result, {'url': 'http://x/foto.jpg'});
    expect(contentType, startsWith('multipart/form-data'));
    final body = utf8.decode(receivedBody!, allowMalformed: true);
    expect(body, contains('contenido-jpg'));
    expect(body, contains('filename="foto.jpg"'));
    expect(body, contains('display_order'));
  });

  test('uploadFile con 401 refresca y reintenta', () async {
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
      if (req.headers['Authorization'] == 'Bearer viejo') {
        return http.Response(jsonEncode({'error': 'token inválido'}), 401);
      }
      return http.Response(jsonEncode({'url': 'http://x/foto.jpg'}), 200);
    });

    final api = ApiClient(
        baseUrl: 'http://x', tokens: TokenStore(prefs), httpClient: mock);
    final result = await api.uploadFile('/photos',
        bytes: utf8.encode('x'), filename: 'upload_test.jpg');

    expect(calls, ['/photos', '/auth/refresh', '/photos']);
    expect(result, {'url': 'http://x/foto.jpg'});
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
