import 'dart:typed_data';
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

  test('setPhotos guarda bytes y nombre (sin paths de dart:io)', () {
    final notifier = container.read(postListingFormProvider.notifier);
    final photo = PickedPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'carta.jpg',
    );
    notifier.setPhotos([photo]);

    final form = container.read(postListingFormProvider);
    expect(form.photos, hasLength(1));
    expect(form.photos.first.filename, 'carta.jpg');
    expect(form.photos.first.bytes, [1, 2, 3]);
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
