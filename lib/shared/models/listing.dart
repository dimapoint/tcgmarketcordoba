import '../../core/api/api_urls.dart';

class ListingPhoto {
  final String url;
  final int displayOrder;
  const ListingPhoto({required this.url, required this.displayOrder});

  factory ListingPhoto.fromJson(Map<String, dynamic> j) => ListingPhoto(
    url: j['url'] as String,
    displayOrder: j['display_order'] as int,
  );
}

class Listing {
  final String id;
  final String sellerId;
  final String cardName;
  final String setName;
  final bool isFoil;
  final String condition;
  final double price;
  final String? description;
  final String status;
  final String sellerUsername;
  final String sellerCity;
  final List<ListingPhoto> photos;

  /// Imagen de catálogo de la carta (proxy /card-images), fallback visual
  /// cuando el vendedor no subió fotos propias.
  final String? cardImageUrl;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.sellerId,
    required this.cardName,
    required this.setName,
    required this.isFoil,
    required this.condition,
    required this.price,
    this.description,
    required this.status,
    required this.sellerUsername,
    required this.sellerCity,
    required this.photos,
    this.cardImageUrl,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        cardName: j['card_name'] as String,
        setName: j['set_name'] as String,
        isFoil: j['is_foil'] as bool,
        condition: j['condition'] as String,
        price: (j['price'] as num).toDouble(),
        description: j['description'] as String?,
        status: j['status'] as String,
        sellerUsername: j['seller_username'] as String,
        sellerCity: j['seller_city'] as String,
        photos: (j['photos'] as List<dynamic>? ?? [])
            .map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>))
            .toList(),
        cardImageUrl: j['card_image_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String? cardImageThumb(int width) => imageWithWidth(cardImageUrl, width);
}
