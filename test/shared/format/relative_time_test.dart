import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/format/relative_time.dart';

void main() {
  final now = DateTime.utc(2026, 7, 15, 12);

  test('recién para menos de un minuto', () {
    expect(relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'recién');
  });

  test('minutos', () {
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        'hace 5 min');
  });

  test('horas', () {
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        'hace 3 h');
  });

  test('días', () {
    expect(relativeTime(now.subtract(const Duration(days: 2)), now: now),
        'hace 2 días');
  });

  test('un día singular', () {
    expect(relativeTime(now.subtract(const Duration(days: 1)), now: now),
        'hace 1 día');
  });

  test('semanas', () {
    expect(relativeTime(now.subtract(const Duration(days: 14)), now: now),
        'hace 2 semanas');
  });

  test('fecha corta para más de dos meses', () {
    expect(
        relativeTime(DateTime.utc(2026, 1, 10, 12), now: now), '10 ene 2026');
  });
}
