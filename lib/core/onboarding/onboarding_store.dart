import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  final SharedPreferences _prefs;
  OnboardingStore(this._prefs);

  static const _kLastSeenVersion = 'onboarding.last_seen_version';

  /// 0 = nunca vio ningún onboarding (usuario nuevo o dispositivo nuevo).
  int lastSeenVersion() => _prefs.getInt(_kLastSeenVersion) ?? 0;

  Future<void> markSeen(int version) =>
      _prefs.setInt(_kLastSeenVersion, version);
}
