import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';

void main() {
  test('fromJson parsea todos los campos', () {
    final order = WantedOrder.fromJson({
      'id': 'b1',
      'buyer_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'min_condition': 'MP',
      'max_price': 1000.5,
      'quantity': 4,
      'description': 'Busco urgente',
      'status': 'active',
      'buyer_username': 'agus',
      'buyer_city': 'Córdoba',
      'matching_listings_count': 3,
      'created_at': '2026-07-04T12:00:00Z',
    });

    expect(order.id, 'b1');
    expect(order.minCondition, 'MP');
    expect(order.maxPrice, 1000.5);
    expect(order.quantity, 4);
    expect(order.matchingListingsCount, 3);
  });

  test('fromJson tolera min_condition y matching_listings_count ausentes', () {
    final order = WantedOrder.fromJson({
      'id': 'b1',
      'buyer_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'min_condition': null,
      'max_price': 100,
      'quantity': 1,
      'description': null,
      'status': 'active',
      'buyer_username': 'agus',
      'buyer_city': 'Córdoba',
      'created_at': '2026-07-04T12:00:00Z',
    });

    expect(order.minCondition, isNull);
    expect(order.matchingListingsCount, 0);
    expect(order.cardImageUrl, isNull);
  });

  test('fromJson parsea card_image_url y cardImageThumb pide la variante chica',
      () {
    final order = WantedOrder.fromJson({
      'id': 'b1',
      'buyer_id': 'u1',
      'card_name': 'Jinx',
      'set_name': 'Origins',
      'is_foil': false,
      'min_condition': null,
      'max_price': 100,
      'quantity': 1,
      'description': null,
      'status': 'active',
      'buyer_username': 'agus',
      'buyer_city': 'Córdoba',
      'created_at': '2026-07-04T12:00:00Z',
      'card_image_url': 'http://api.local/card-images/abc.png',
    });

    expect(order.cardImageUrl, 'http://api.local/card-images/abc.png');
    expect(
        order.cardImageThumb(120), 'http://api.local/card-images/abc.png?w=120');
  });
}
