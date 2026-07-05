import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/features/onboarding/onboarding_content.dart';

void main() {
  test('kOnboardingLatestVersion es el máximo de kOnboardingSlides', () {
    final maxVersion =
        kOnboardingSlides.map((s) => s.version).reduce((a, b) => a > b ? a : b);
    expect(kOnboardingLatestVersion, maxVersion);
  });

  test('kOnboardingSlides no está vacía', () {
    expect(kOnboardingSlides, isNotEmpty);
  });
}
