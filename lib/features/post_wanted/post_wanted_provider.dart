import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/card_printing.dart';
import '../post_listing/card_repository.dart';

class PostWantedForm {
  final CardPrinting? cardPrinting;
  final String? minCondition;
  final double maxPrice;
  final int quantity;
  final String? description;
  final String? cityId;

  const PostWantedForm({
    this.cardPrinting,
    this.minCondition,
    this.maxPrice = 0,
    this.quantity = 1,
    this.description,
    this.cityId,
  });

  // La condición es opcional (cualquiera vale si no se especifica) y
  // cityId también es opcional: el backend usa la ciudad del perfil como
  // fallback, igual que en post_listing.
  bool get isValid => cardPrinting != null && maxPrice > 0;

  PostWantedForm copyWith({
    CardPrinting? cardPrinting,
    String? minCondition,
    bool clearMinCondition = false,
    double? maxPrice,
    int? quantity,
    String? description,
    String? cityId,
  }) =>
      PostWantedForm(
        cardPrinting: cardPrinting ?? this.cardPrinting,
        minCondition:
            clearMinCondition ? null : (minCondition ?? this.minCondition),
        maxPrice: maxPrice ?? this.maxPrice,
        quantity: quantity ?? this.quantity,
        description: description ?? this.description,
        cityId: cityId ?? this.cityId,
      );
}

class PostWantedFormNotifier extends Notifier<PostWantedForm> {
  @override
  PostWantedForm build() => const PostWantedForm();

  void setCardPrinting(CardPrinting cp) =>
      state = state.copyWith(cardPrinting: cp);
  void setMinCondition(String? c) => state = c == null
      ? state.copyWith(clearMinCondition: true)
      : state.copyWith(minCondition: c);
  void setMaxPrice(double p) => state = state.copyWith(maxPrice: p);
  void setQuantity(int q) => state = state.copyWith(quantity: q);
  void setDescription(String? d) => state = state.copyWith(description: d);
  void setCityId(String id) => state = state.copyWith(cityId: id);
  void reset() => state = const PostWantedForm();
}

final postWantedFormProvider =
    NotifierProvider<PostWantedFormNotifier, PostWantedForm>(
  PostWantedFormNotifier.new,
);

// Reutiliza la búsqueda de cartas de post_listing: mismo CardRepository,
// mismo debounce por query — no tiene sentido duplicarla.
final wantedCardSearchQueryProvider = StateProvider<String>((ref) => '');

final wantedCardSearchResultsProvider =
    FutureProvider.autoDispose<List<CardPrinting>>((ref) {
  final query = ref.watch(wantedCardSearchQueryProvider);
  if (query.length < 2) return Future.value([]);
  return ref.watch(cardRepositoryProvider).search(query);
});
