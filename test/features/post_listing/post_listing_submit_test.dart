import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/features/post_listing/photo_repository.dart';
import 'package:tcgmarketcordoba/features/post_listing/post_listing_provider.dart';
import 'package:tcgmarketcordoba/features/post_listing/post_listing_repository.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';

class _FakeListingRepo implements PostListingRepository {
  int calls = 0;
  Completer<String>? gate; // si está seteado, createListing espera acá

  @override
  Future<String> createListing({
    required String cardPrintingId,
    required String condition,
    required double price,
    String? description,
    String? cityId,
  }) async {
    calls++;
    if (gate != null) return gate!.future;
    return 'l1';
  }
}

class _FakePhotoRepo implements PhotoRepository {
  final uploaded = <(String, String, int)>[]; // (listingId, filename, order)
  Object? throwOnUpload;

  @override
  Future<String> upload({
    required String listingId,
    required List<int> bytes,
    required String filename,
    required int order,
  }) async {
    if (throwOnUpload != null) throw throwOnUpload!;
    uploaded.add((listingId, filename, order));
    return 'http://x/$filename';
  }
}

const _jinx = CardPrinting(
  id: 'cp-1',
  cardId: 'c-1',
  cardName: 'Jinx',
  setName: 'Origins',
  setCode: 'OGN',
  cardNumber: '001',
  isFoil: false,
);

void main() {
  late _FakeListingRepo listingRepo;
  late _FakePhotoRepo photoRepo;
  late ProviderContainer container;

  setUp(() {
    listingRepo = _FakeListingRepo();
    photoRepo = _FakePhotoRepo();
    container = ProviderContainer(overrides: [
      postListingRepositoryProvider.overrideWithValue(listingRepo),
      photoRepositoryProvider.overrideWithValue(photoRepo),
    ]);
  });

  tearDown(() => container.dispose());

  void fillValidForm({int photos = 0}) {
    final form = container.read(postListingFormProvider.notifier);
    form.setCardPrinting(_jinx);
    form.setCondition('NM');
    form.setPrice(3200);
    form.setPhotos([
      for (var i = 0; i < photos; i++)
        PickedPhoto(
            bytes: Uint8List.fromList([i]), filename: 'foto$i.jpg'),
    ]);
  }

  test('éxito: crea listing, sube fotos en orden y resetea el form', () async {
    fillValidForm(photos: 2);
    final submit = container.read(postListingSubmitProvider.notifier);

    final result = await submit.submit();

    expect(result, isA<SubmitSuccess>());
    expect(listingRepo.calls, 1);
    expect(photoRepo.uploaded, [
      ('l1', 'foto0.jpg', 1),
      ('l1', 'foto1.jpg', 2),
    ]);
    expect(container.read(postListingFormProvider).cardPrinting, isNull);
    expect(container.read(postListingSubmitProvider), isFalse);
  });

  test('error no-ApiException se captura y el form queda para reintentar',
      () async {
    fillValidForm(photos: 1);
    photoRepo.throwOnUpload = UnsupportedError('sin dart:io en web');
    final submit = container.read(postListingSubmitProvider.notifier);

    final result = await submit.submit();

    expect(result, isA<SubmitFailure>());
    expect((result as SubmitFailure).message, contains('foto'));
    // El form NO se resetea: el usuario puede corregir y reintentar.
    expect(container.read(postListingFormProvider).cardPrinting, isNotNull);
    expect(container.read(postListingSubmitProvider), isFalse);
  });

  test('doble submit en vuelo: el segundo se ignora y no duplica', () async {
    fillValidForm();
    listingRepo.gate = Completer<String>();
    final submit = container.read(postListingSubmitProvider.notifier);

    final first = submit.submit();
    expect(container.read(postListingSubmitProvider), isTrue);
    final second = await submit.submit();

    expect(second, isA<SubmitSkipped>());
    expect(listingRepo.calls, 1);

    listingRepo.gate!.complete('l1');
    expect(await first, isA<SubmitSuccess>());
  });

  test('form inválido: no llama al backend', () async {
    final submit = container.read(postListingSubmitProvider.notifier);
    final result = await submit.submit();

    expect(result, isA<SubmitSkipped>());
    expect(listingRepo.calls, 0);
  });
}
