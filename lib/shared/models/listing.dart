class ListingPhoto {
  final String storagePath;
  final int displayOrder;
  const ListingPhoto({required this.storagePath, required this.displayOrder});

  factory ListingPhoto.fromJson(Map<String, dynamic> j) => ListingPhoto(
    storagePath: j['storage_path'] as String,
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
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) {
    final cp = j['card_printings'] as Map<String, dynamic>;
    final card = cp['cards'] as Map<String, dynamic>;
    final set_ = cp['sets'] as Map<String, dynamic>;
    final seller = j['profiles'] as Map<String, dynamic>;
    final city = seller['cities'] as Map<String, dynamic>;
    final rawPhotos = j['listing_photos'] as List<dynamic>? ?? [];

    return Listing(
      id: j['id'] as String,
      sellerId: j['seller_id'] as String,
      cardName: card['name'] as String,
      setName: set_['name'] as String,
      isFoil: cp['is_foil'] as bool,
      condition: j['condition'] as String,
      price: (j['price'] as num).toDouble(),
      description: j['description'] as String?,
      status: j['status'] as String,
      sellerUsername: seller['username'] as String,
      sellerCity: city['name'] as String,
      photos:
          rawPhotos
              .map((p) => ListingPhoto.fromJson(p as Map<String, dynamic>))
              .toList(),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}
