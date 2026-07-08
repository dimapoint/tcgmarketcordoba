import '../../core/api/api_urls.dart';

class WantedOrder {
  final String id;
  final String buyerId;
  final String cardName;
  final String setName;
  final bool isFoil;
  final String? minCondition;
  final double maxPrice;
  final int quantity;
  final String? description;
  final String status;
  final String buyerUsername;
  final String buyerCity;
  final int matchingListingsCount;

  /// Imagen de catálogo de la carta buscada (proxy /card-images).
  final String? cardImageUrl;
  final DateTime createdAt;

  const WantedOrder({
    required this.id,
    required this.buyerId,
    required this.cardName,
    required this.setName,
    required this.isFoil,
    this.minCondition,
    required this.maxPrice,
    required this.quantity,
    this.description,
    required this.status,
    required this.buyerUsername,
    required this.buyerCity,
    this.matchingListingsCount = 0,
    this.cardImageUrl,
    required this.createdAt,
  });

  factory WantedOrder.fromJson(Map<String, dynamic> j) => WantedOrder(
        id: j['id'] as String,
        buyerId: j['buyer_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        isFoil: j['is_foil'] as bool,
        minCondition: j['min_condition'] as String?,
        maxPrice: (j['max_price'] as num).toDouble(),
        quantity: j['quantity'] as int,
        description: j['description'] as String?,
        status: j['status'] as String,
        buyerUsername: j['buyer_username'] as String,
        buyerCity: j['buyer_city'] as String,
        matchingListingsCount: j['matching_listings_count'] as int? ?? 0,
        cardImageUrl: j['card_image_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String? cardImageThumb(int width) => imageWithWidth(cardImageUrl, width);
}
