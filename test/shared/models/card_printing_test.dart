import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';

CardPrinting _printing(String? imageUrl) => CardPrinting(
      id: 'p1',
      cardId: 'c1',
      cardName: 'Jinx',
      setName: 'Origins',
      setCode: 'OGN',
      cardNumber: '001',
      isFoil: false,
      imageUrl: imageUrl,
    );

void main() {
  test('thumbnailUrl pide la variante chica al proxy', () {
    final p = _printing('http://api.local/card-images/abc.png');
    expect(p.thumbnailUrl, 'http://api.local/card-images/abc.png?w=120');
  });

  test('thumbnailUrl es null sin imagen', () {
    expect(_printing(null).thumbnailUrl, isNull);
  });

  test('thumbnailUrl no toca URLs que ya tienen query', () {
    final p = _printing('https://otro.cdn/x.png?token=1');
    expect(p.thumbnailUrl, 'https://otro.cdn/x.png?token=1');
  });
}
