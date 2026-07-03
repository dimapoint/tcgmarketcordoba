import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';

class TokenStore {
  final SharedPreferences _prefs;
  TokenStore(this._prefs);

  static const _kAccess = 'auth.access_token';
  static const _kRefresh = 'auth.refresh_token';
  static const _kUserId = 'auth.user_id';
  static const _kEmail = 'auth.email';

  AuthSession? load() {
    final access = _prefs.getString(_kAccess);
    final refresh = _prefs.getString(_kRefresh);
    final userId = _prefs.getString(_kUserId);
    final email = _prefs.getString(_kEmail);
    if (access == null || refresh == null || userId == null || email == null) {
      return null;
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: AuthUser(id: userId, email: email),
    );
  }

  Future<void> save(AuthSession s) async {
    await _prefs.setString(_kAccess, s.accessToken);
    await _prefs.setString(_kRefresh, s.refreshToken);
    await _prefs.setString(_kUserId, s.user.id);
    await _prefs.setString(_kEmail, s.user.email);
  }

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kEmail);
  }
}
