import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/price_reference.dart';

void main() {
  test('fromJson con todos los datos', () {
    final ref = PriceReference.fromJson(const {
      'market_usd': 15.26,
      'market_ars': 23000,
      'fx_rate': 1510,
      'is_foil': true,
      'local_active_count': 3,
      'local_min_price': 10000,
    });
    expect(ref.marketUsd, 15.26);
    expect(ref.marketArs, 23000);
    expect(ref.fxRate, 1510);
    expect(ref.isFoil, isTrue);
    expect(ref.localActiveCount, 3);
    expect(ref.localMinPrice, 10000);
    expect(ref.hasData, isTrue);
  });

  test('fromJson degradado: solo nulls y ceros', () {
    final ref = PriceReference.fromJson(const {
      'market_usd': null,
      'market_ars': null,
      'fx_rate': null,
      'is_foil': false,
      'local_active_count': 0,
      'local_min_price': null,
    });
    expect(ref.marketUsd, isNull);
    expect(ref.marketArs, isNull);
    expect(ref.localMinPrice, isNull);
    expect(ref.hasData, isFalse);
  });

  test('hasData con solo datos locales', () {
    final ref = PriceReference.fromJson(const {
      'market_usd': null,
      'market_ars': null,
      'fx_rate': null,
      'is_foil': false,
      'local_active_count': 2,
      'local_min_price': 5000,
    });
    expect(ref.hasData, isTrue);
  });
}
