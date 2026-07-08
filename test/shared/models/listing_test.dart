import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';

Map<String, dynamic> _json({String? cardImageUrl, bool includeKey = true}) => {
      'id': 'l1',
      'seller_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'condition': 'NM',
      'price': 1000.0,
      'description': null,
      'status': 'active',
      'seller_username': 'vendedor',
      'seller_city': 'Córdoba',
      'photos': <dynamic>[],
      'created_at': '2026-07-08T00:00:00Z',
      if (includeKey) 'card_image_url': cardImageUrl,
    };

void main() {
  test('fromJson parsea card_image_url', () {
    final l = Listing.fromJson(_json(cardImageUrl: '/card-images/abc.png'));
    expect(l.cardImageUrl, '/card-images/abc.png');
  });

  test('fromJson tolera card_image_url ausente (respuestas viejas)', () {
    final l = Listing.fromJson(_json(includeKey: false));
    expect(l.cardImageUrl, isNull);
  });

  test('cardImageThumb pide la variante chica al proxy', () {
    final l = Listing.fromJson(
        _json(cardImageUrl: 'http://api.local/card-images/abc.png'));
    expect(l.cardImageThumb(400), 'http://api.local/card-images/abc.png?w=400');
  });

  test('cardImageThumb es null sin imagen', () {
    final l = Listing.fromJson(_json(cardImageUrl: null));
    expect(l.cardImageThumb(400), isNull);
  });
}
