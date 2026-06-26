import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

void main() {
  group('Listing.fromJson', () {
    test('parses correctly from nested Supabase JSON', () {
      final json = {
        'id': 'listing-1',
        'seller_id': 'seller-uuid-1',
        'condition': 'NM',
        'price': 500.0,
        'description': null,
        'status': 'active',
        'created_at': '2026-06-26T10:00:00Z',
        'card_printings': {
          'is_foil': false,
          'cards': {'name': 'Jinx'},
          'sets': {'name': 'Origins'},
        },
        'profiles': {
          'username': 'vendedor1',
          'cities': {'name': 'Córdoba'},
        },
        'listing_photos': [
          {'storage_path': 'path/to/photo.jpg', 'display_order': 1},
        ],
      };

      final listing = Listing.fromJson(json);

      expect(listing.cardName, 'Jinx');
      expect(listing.setName, 'Origins');
      expect(listing.condition, 'NM');
      expect(listing.price, 500.0);
      expect(listing.sellerId, 'seller-uuid-1');
      expect(listing.sellerCity, 'Córdoba');
      expect(listing.photos.length, 1);
      expect(listing.photos.first.displayOrder, 1);
    });
  });
}
