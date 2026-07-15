import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/card_printing.dart';
import '../../shared/state/value_state.dart';
import 'card_repository.dart';
import 'photo_repository.dart';
import 'post_listing_repository.dart';

/// Foto elegida por el usuario, ya leída a memoria.
/// Se guardan bytes (no paths): en web el path del picker es una blob URL
/// que dart:io no puede abrir.
class PickedPhoto {
  final Uint8List bytes;
  final String filename;
  const PickedPhoto({required this.bytes, required this.filename});
}

class PostListingForm {
  final CardPrinting? cardPrinting;
  final String? condition;
  final double price;
  final int quantity;
  final String? description;
  final List<PickedPhoto> photos;
  final String? cityId;

  const PostListingForm({
    this.cardPrinting,
    this.condition,
    this.price = 0,
    this.quantity = 1,
    this.description,
    this.photos = const [],
    this.cityId,
  });

  // cityId es opcional: el backend usa la ciudad del perfil como fallback.
  // Las fotos también son opcionales.
  bool get isValid =>
      cardPrinting != null && condition != null && price > 0;

  PostListingForm copyWith({
    CardPrinting? cardPrinting,
    String? condition,
    double? price,
    int? quantity,
    String? description,
    List<PickedPhoto>? photos,
    String? cityId,
  }) =>
      PostListingForm(
        cardPrinting: cardPrinting ?? this.cardPrinting,
        condition: condition ?? this.condition,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        description: description ?? this.description,
        photos: photos ?? this.photos,
        cityId: cityId ?? this.cityId,
      );
}

class PostListingFormNotifier extends Notifier<PostListingForm> {
  @override
  PostListingForm build() => const PostListingForm();

  void setCardPrinting(CardPrinting cp) =>
      state = state.copyWith(cardPrinting: cp);
  void setCondition(String c) => state = state.copyWith(condition: c);
  void setPrice(double p) => state = state.copyWith(price: p);
  void setQuantity(int q) => state = state.copyWith(quantity: q);
  void setDescription(String? d) => state = state.copyWith(description: d);
  void setPhotos(List<PickedPhoto> photos) =>
      state = state.copyWith(photos: photos);
  void setCityId(String id) => state = state.copyWith(cityId: id);
  void reset() => state = const PostListingForm();
}

final postListingFormProvider =
    NotifierProvider<PostListingFormNotifier, PostListingForm>(
  PostListingFormNotifier.new,
);

sealed class SubmitResult {}

class SubmitSuccess extends SubmitResult {}

class SubmitFailure extends SubmitResult {
  final String message;
  SubmitFailure(this.message);
}

/// Envío ignorado: ya hay uno en curso o el form es inválido.
class SubmitSkipped extends SubmitResult {}

/// Estado = true mientras hay un envío en curso (deshabilita el botón).
/// Centraliza el submit para que ningún error quede sin superficie: el bug
/// original era un UnsupportedError de dart:io que escapaba a un
/// `on ApiException` y dejaba la pantalla muda con el listing ya creado.
class PostListingSubmitNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<SubmitResult> submit() async {
    if (state) return SubmitSkipped();
    final form = ref.read(postListingFormProvider);
    if (!form.isValid) return SubmitSkipped();

    state = true;
    try {
      final listingId =
          await ref.read(postListingRepositoryProvider).createListing(
                cardPrintingId: form.cardPrinting!.id,
                condition: form.condition!,
                price: form.price,
                quantity: form.quantity,
                description: form.description,
                cityId: form.cityId,
              );

      final photoRepo = ref.read(photoRepositoryProvider);
      for (var i = 0; i < form.photos.length; i++) {
        try {
          await photoRepo.upload(
            listingId: listingId,
            bytes: form.photos[i].bytes,
            filename: form.photos[i].filename,
            order: i + 1,
          );
        } catch (e) {
          // El listing ya existe; que el mensaje no sugiera reintentar todo.
          final detail = e is ApiException ? e.message : '$e';
          return SubmitFailure(
              'La publicación se creó pero falló la foto ${i + 1}: $detail');
        }
      }

      ref.read(postListingFormProvider.notifier).reset();
      return SubmitSuccess();
    } on ApiException catch (e) {
      return SubmitFailure(e.message);
    } catch (e) {
      return SubmitFailure('No se pudo publicar: $e');
    } finally {
      state = false;
    }
  }
}

final postListingSubmitProvider =
    NotifierProvider<PostListingSubmitNotifier, bool>(
  PostListingSubmitNotifier.new,
);

final cardSearchQueryProvider = valueStateProvider<String>('');

final cardSearchResultsProvider =
    FutureProvider.autoDispose<List<CardPrinting>>((ref) {
  final query = ref.watch(cardSearchQueryProvider);
  if (query.length < 2) return Future.value([]);
  return ref.watch(cardRepositoryProvider).search(query);
});
