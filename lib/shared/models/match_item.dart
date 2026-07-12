import '../../core/api/api_urls.dart';

/// Un listing activo de otro usuario que matchea una búsqueda activa propia.
class MatchItem {
  final String listingId;
  final String cardName;
  final String setName;
  final bool isFoil;
  final String condition;
  final double price;
  final String sellerUsername;

  /// Imagen de catálogo de la carta (proxy /card-images).
  final String? cardImageUrl;
  final DateTime createdAt;

  /// Apareció después de la última vez que el usuario vio sus novedades.
  final bool isNew;

  const MatchItem({
    required this.listingId,
    required this.cardName,
    required this.setName,
    required this.isFoil,
    required this.condition,
    required this.price,
    required this.sellerUsername,
    this.cardImageUrl,
    required this.createdAt,
    required this.isNew,
  });

  factory MatchItem.fromJson(Map<String, dynamic> j) => MatchItem(
        listingId: j['listing_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        isFoil: j['is_foil'] as bool,
        condition: j['condition'] as String,
        price: (j['price'] as num).toDouble(),
        sellerUsername: j['seller_username'] as String,
        cardImageUrl: j['card_image_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        isNew: j['is_new'] as bool? ?? false,
      );

  String? cardImageThumb(int width) => imageWithWidth(cardImageUrl, width);
}
