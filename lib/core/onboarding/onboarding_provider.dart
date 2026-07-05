import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_store.dart';

/// Overrideado en main.dart con la instancia real inicializada.
final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => throw UnimplementedError('onboardingStoreProvider must be overridden'),
);
