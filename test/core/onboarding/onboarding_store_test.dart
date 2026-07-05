import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcgmarketcordoba/core/onboarding/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lastSeenVersion() es 0 con prefs vacías', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore(await SharedPreferences.getInstance());
    expect(store.lastSeenVersion(), 0);
  });

  test('markSeen actualiza lastSeenVersion', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore(await SharedPreferences.getInstance());
    await store.markSeen(2);
    expect(store.lastSeenVersion(), 2);
  });

  test('persiste entre instancias sobre las mismas prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStore(prefs).markSeen(3);

    final reloaded = OnboardingStore(await SharedPreferences.getInstance());
    expect(reloaded.lastSeenVersion(), 3);
  });
}
