import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';
import 'package:tcgmarketcordoba/features/post_wanted/post_wanted_provider.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';

@GenerateMocks([CardRepository])
import 'post_wanted_provider_test.mocks.dart';

void main() {
  late MockCardRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockCardRepository();
    container = ProviderContainer(overrides: [
      cardRepositoryProvider.overrideWithValue(mockRepo),
    ]);
  });

  tearDown(() => container.dispose());

  test('form is invalid when max price is zero', () {
    final notifier = container.read(postWantedFormProvider.notifier);
    notifier.setMaxPrice(0);
    expect(container.read(postWantedFormProvider).isValid, isFalse);
  });

  test('form is valid without min condition (cualquier condición vale)', () {
    final notifier = container.read(postWantedFormProvider.notifier);
    notifier.setCardPrinting(const CardPrinting(
      id: '1',
      cardId: '1',
      cardName: 'Jinx',
      setName: 'Origins',
      setCode: 'OGN',
      cardNumber: '001',
      isFoil: false,
    ));
    notifier.setMaxPrice(100);
    expect(container.read(postWantedFormProvider).isValid, isTrue);
    expect(container.read(postWantedFormProvider).minCondition, isNull);
  });

  test('form is invalid without a card printing', () {
    final notifier = container.read(postWantedFormProvider.notifier);
    notifier.setMaxPrice(100);
    expect(container.read(postWantedFormProvider).isValid, isFalse);
  });

  test('quantity defaults to 1', () {
    expect(container.read(postWantedFormProvider).quantity, 1);
  });
}
