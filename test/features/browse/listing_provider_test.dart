import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

void main() {
  group('Listing.fromJson', () {
    test('parses flat API JSON', () {
      final json = {
        'id': 'listing-1',
        'seller_id': 'seller-uuid-1',
        'card_name': 'Jinx',
        'set_name': 'Origins',
        'is_foil': false,
        'condition': 'NM',
        'price': 500.0,
        'description': null,
        'status': 'active',
        'seller_username': 'vendedor1',
        'seller_city': 'Córdoba',
        'created_at': '2026-06-26T10:00:00Z',
        'photos': [
          {'url': 'https://cdn/x.jpg', 'display_order': 1},
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
      expect(listing.photos.first.url, 'https://cdn/x.jpg');
      expect(listing.photos.first.displayOrder, 1);
    });

    test('tolerates missing photos', () {
      final listing = Listing.fromJson({
        'id': 'l2',
        'seller_id': 's1',
        'card_name': 'Vi',
        'set_name': 'Origins',
        'is_foil': true,
        'condition': 'LP',
        'price': 100,
        'description': 'desc',
        'status': 'active',
        'seller_username': 'v',
        'seller_city': 'Río Cuarto',
        'created_at': '2026-06-26T10:00:00Z',
      });
      expect(listing.photos, isEmpty);
    });
  });
}
