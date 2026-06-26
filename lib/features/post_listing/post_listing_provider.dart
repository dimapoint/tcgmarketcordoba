import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/card_printing.dart';
import 'card_repository.dart';

class PostListingForm {
  final CardPrinting? cardPrinting;
  final String? condition;
  final double price;
  final String? description;
  final List<String> photoPaths;
  final String? cityId;

  const PostListingForm({
    this.cardPrinting,
    this.condition,
    this.price = 0,
    this.description,
    this.photoPaths = const [],
    this.cityId,
  });

  bool get isValid =>
      cardPrinting != null &&
      condition != null &&
      price > 0 &&
      photoPaths.isNotEmpty &&
      cityId != null;

  PostListingForm copyWith({
    CardPrinting? cardPrinting,
    String? condition,
    double? price,
    String? description,
    List<String>? photoPaths,
    String? cityId,
  }) =>
      PostListingForm(
        cardPrinting: cardPrinting ?? this.cardPrinting,
        condition: condition ?? this.condition,
        price: price ?? this.price,
        description: description ?? this.description,
        photoPaths: photoPaths ?? this.photoPaths,
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
  void setDescription(String? d) => state = state.copyWith(description: d);
  void setPhotoPaths(List<String> paths) =>
      state = state.copyWith(photoPaths: paths);
  void setCityId(String id) => state = state.copyWith(cityId: id);
  void reset() => state = const PostListingForm();
}

final postListingFormProvider =
    NotifierProvider<PostListingFormNotifier, PostListingForm>(
  PostListingFormNotifier.new,
);

final cardSearchQueryProvider = StateProvider<String>((ref) => '');

final cardSearchResultsProvider =
    FutureProvider.autoDispose<List<CardPrinting>>((ref) {
  final query = ref.watch(cardSearchQueryProvider);
  if (query.length < 2) return Future.value([]);
  return ref.watch(cardRepositoryProvider).search(query);
});
