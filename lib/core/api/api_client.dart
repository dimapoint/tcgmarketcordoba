import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'token_store.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final TokenStore _tokens;
  final http.Client _http;
  AuthSession? _session;
  final _controller = StreamController<AuthSession?>.broadcast();

  ApiClient({
    required this.baseUrl,
    required TokenStore tokens,
    http.Client? httpClient,
  })  // campo privado con parámetro nombrado: no aplica this._tokens
      // ignore: prefer_initializing_formals
      : _tokens = tokens,
        _http = httpClient ?? http.Client() {
    _session = _tokens.load();
  }

  AuthSession? get session => _session;

  Stream<AuthSession?> get onSessionChange async* {
    yield _session;
    yield* _controller.stream;
  }

  Future<void> _setSession(AuthSession? s) async {
    _session = s;
    if (s == null) {
      await _tokens.clear();
    } else {
      await _tokens.save(s);
    }
    _controller.add(s);
  }

  // ---- auth ----

  Future<void> signUp({required String email, required String password}) =>
      _authenticate('/auth/signup', email, password);

  Future<void> signIn({required String email, required String password}) =>
      _authenticate('/auth/signin', email, password);

  Future<void> signOut() => _setSession(null);

  Future<void> _authenticate(String path, String email, String password) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    await _setSession(_sessionFromJson(body));
  }

  Future<bool>? _refreshInFlight;

  // Los refresh tokens son de un solo uso (rotación): dos refresh
  // concurrentes con el mismo token deslogueaban al usuario. Se comparte
  // un único refresh en vuelo entre todos los 401 simultáneos.
  Future<bool> _refresh() => _refreshInFlight ??=
      _doRefresh().whenComplete(() => _refreshInFlight = null);

  Future<bool> _doRefresh() async {
    final current = _session;
    if (current == null) return false;
    final res = await _http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': current.refreshToken}),
    );
    if (res.statusCode != 200) {
      await _setSession(null);
      return false;
    }
    await _setSession(
        _sessionFromJson(jsonDecode(res.body) as Map<String, dynamic>));
    return true;
  }

  AuthSession _sessionFromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: j['access_token'] as String,
      refreshToken: j['refresh_token'] as String,
      user: AuthUser(id: u['id'] as String, email: u['email'] as String),
    );
  }

  // ---- requests ----

  Future<dynamic> get(String path,
          {Map<String, String>? query, bool auth = false}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = false}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = false}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> put(String path, {Object? body, bool auth = false}) =>
      _send('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = false}) =>
      _send('DELETE', path, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = false,
    bool retried = false,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final req = http.Request(method, uri);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (auth) {
      final s = _session;
      if (s == null) throw ApiException(401, 'No hay sesión activa');
      req.headers['Authorization'] = 'Bearer ${s.accessToken}';
    }
    final res = await http.Response.fromStream(await _http.send(req));
    if (auth && res.statusCode == 401 && !retried) {
      if (await _refresh()) {
        return _send(method, path,
            query: query, body: body, auth: auth, retried: true);
      }
    }
    return _decode(res);
  }

  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    Map<String, String> fields = const {},
    bool retried = false,
  }) async {
    final s = _session;
    if (s == null) throw ApiException(401, 'No hay sesión activa');
    // Un MultipartRequest finalizado no se puede reenviar: el reintento
    // reconstruye el request desde cero.
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer ${s.accessToken}'
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 401 && !retried && await _refresh()) {
      return uploadFile(path, filePath: filePath, fields: fields, retried: true);
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    var msg = 'Error ${res.statusCode}';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map && j['error'] is String) msg = j['error'] as String;
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }
}
