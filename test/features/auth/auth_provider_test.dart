import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tcgmarketcordoba/features/auth/auth_repository.dart';
import 'package:tcgmarketcordoba/features/auth/auth_provider.dart';

@GenerateMocks([AuthRepository])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository();
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(mockRepo),
    ]);
  });

  tearDown(() => container.dispose());

  test('signIn calls repository and completes', () async {
    when(mockRepo.signIn(email: 'a@b.com', password: '123456'))
        .thenAnswer((_) async {});

    await container.read(authActionsProvider.notifier).signIn(
      email: 'a@b.com',
      password: '123456',
    );

    verify(mockRepo.signIn(email: 'a@b.com', password: '123456')).called(1);
  });

  test('signInWithGoogle calls repository', () async {
    when(mockRepo.signInWithGoogle('tok')).thenAnswer((_) async {});

    await container
        .read(authActionsProvider.notifier)
        .signInWithGoogle('tok');

    verify(mockRepo.signInWithGoogle('tok')).called(1);
    expect(container.read(authActionsProvider).hasError, isFalse);
  });

  test('signIn sets error state on failure', () async {
    when(mockRepo.signIn(
            email: anyNamed('email'), password: anyNamed('password')))
        .thenThrow(Exception('Invalid credentials'));

    await container.read(authActionsProvider.notifier).signIn(
      email: 'bad@b.com',
      password: 'wrong',
    );

    final state = container.read(authActionsProvider);
    expect(state.hasError, isTrue);
  });
}
