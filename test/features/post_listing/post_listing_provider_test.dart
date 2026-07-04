import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';
import 'package:tcgmarketcordoba/features/post_listing/post_listing_provider.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';

@GenerateMocks([CardRepository])
import 'post_listing_provider_test.mocks.dart';

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

  test('form is invalid when price is zero', () {
    final notifier = container.read(postListingFormProvider.notifier);
    notifier.setPrice(0);
    expect(container.read(postListingFormProvider).isValid, isFalse);
  });

  test('form is valid without photos (las fotos son opcionales)', () {
    final notifier = container.read(postListingFormProvider.notifier);
    notifier.setCardPrinting(const CardPrinting(
      id: '1',
      cardId: '1',
      cardName: 'Jinx',
      setName: 'Origins',
      setCode: 'OGN',
      cardNumber: '001',
      isFoil: false,
    ));
    notifier.setCondition('NM');
    notifier.setPrice(100);
    expect(container.read(postListingFormProvider).isValid, isTrue);
  });

  test('form is invalid without condition', () {
    final notifier = container.read(postListingFormProvider.notifier);
    notifier.setCardPrinting(const CardPrinting(
      id: '1',
      cardId: '1',
      cardName: 'Jinx',
      setName: 'Origins',
      setCode: 'OGN',
      cardNumber: '001',
      isFoil: false,
    ));
    notifier.setPrice(100);
    expect(container.read(postListingFormProvider).isValid, isFalse);
  });
}
