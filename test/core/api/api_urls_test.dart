import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/core/api/api_urls.dart';

void main() {
  group('absoluteApiUrl', () {
    test('ruta relativa se prefija con baseUrl', () {
      expect(
        absoluteApiUrl('/card-images/abc.png', 'http://api.local'),
        'http://api.local/card-images/abc.png',
      );
    });

    test('URL absoluta queda igual', () {
      expect(
        absoluteApiUrl('https://otro.cdn/x.png', 'http://api.local'),
        'https://otro.cdn/x.png',
      );
    });

    test('null queda null', () {
      expect(absoluteApiUrl(null, 'http://api.local'), isNull);
    });
  });

  group('imageWithWidth', () {
    test('agrega ?w= a la URL', () {
      expect(
        imageWithWidth('http://api.local/card-images/abc.png', 120),
        'http://api.local/card-images/abc.png?w=120',
      );
    });

    test('no toca URLs que ya tienen query', () {
      expect(
        imageWithWidth('https://otro.cdn/x.png?token=1', 120),
        'https://otro.cdn/x.png?token=1',
      );
    });

    test('null queda null', () {
      expect(imageWithWidth(null, 120), isNull);
    });
  });
}
