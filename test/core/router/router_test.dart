import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';

void main() {
  test('authSessionProvider returns null session when logged out', () async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    final session = await container.read(authSessionProvider.future);
    expect(session, isNull);
  });
}
