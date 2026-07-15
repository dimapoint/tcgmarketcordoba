import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/listing.dart';
import 'package:tcgmarketcordoba/shared/models/wanted_order.dart';
import 'package:tcgmarketcordoba/shared/share/share.dart';

Listing listing({bool foil = false}) => Listing(
      id: 'l1',
      sellerId: 'u1',
      cardPrintingId: 'cp1',
      cardName: 'Jinx',
      setName: 'Origins',
      isFoil: foil,
      condition: 'NM',
      price: 15000,
      status: 'active',
      sellerUsername: 'dima',
      sellerCity: 'Córdoba',
      photos: const [],
      createdAt: DateTime(2026),
    );

void main() {
  test('texto de listado sin foil', () {
    expect(
      listingShareText(listing(), 'https://x/listings/l1'),
      'Vendo Jinx (NM) a \$ 15.000 en TCG Market Córdoba: https://x/listings/l1',
    );
  });

  test('texto de listado foil incluye Foil', () {
    expect(listingShareText(listing(foil: true), 'u'), contains('(Foil, NM)'));
  });

  test('texto de búsqueda', () {
    final o = WantedOrder(
      id: 'b1',
      buyerId: 'u1',
      cardName: 'Viktor',
      setName: 'Origins',
      isFoil: false,
      maxPrice: 8000,
      quantity: 1,
      status: 'active',
      buyerUsername: 'dima',
      buyerCity: 'Córdoba',
      createdAt: DateTime(2026),
    );
    expect(
      wantedShareText(o, 'https://x/buy-orders/b1'),
      'Busco Viktor — pago hasta \$ 8.000 · TCG Market Córdoba: https://x/buy-orders/b1',
    );
  });

  test('texto de carpeta', () {
    expect(
      binderShareText('https://x/u/dima'),
      'Mis cartas en venta en TCG Market Córdoba: https://x/u/dima',
    );
  });
}
