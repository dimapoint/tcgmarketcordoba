import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';
import 'package:tcgmarketcordoba/shared/models/price_reference.dart';
import 'package:tcgmarketcordoba/shared/widgets/price_reference_hint.dart';

class _FakeCardRepository implements CardRepository {
  final PriceReference reference;
  final bool fail;
  _FakeCardRepository(this.reference, {this.fail = false});

  @override
  Future<PriceReference> priceReference(String printingId) async {
    if (fail) throw Exception('api caída');
    return reference;
  }

  @override
  Future<List<CardPrinting>> search(String query) async => const [];
}

Future<void> _pump(
  WidgetTester tester,
  PriceReference ref, {
  bool fail = false,
  ValueChanged<double>? onSuggest,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      cardRepositoryProvider
          .overrideWithValue(_FakeCardRepository(ref, fail: fail)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PriceReferenceHint(
          printingId: 'cp-1',
          onSuggest: onSuggest ?? (_) {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

const _full = PriceReference(
  marketUsd: 15.26,
  marketArs: 23000,
  fxRate: 1510,
  isFoil: true,
  localActiveCount: 3,
  localMinPrice: 10000,
);

void main() {
  testWidgets('muestra mercado y stats locales, y el tap sugiere el ARS',
      (tester) async {
    double? suggested;
    await _pump(tester, _full, onSuggest: (v) => suggested = v);

    expect(find.textContaining('3 en venta'), findsOneWidget);
    expect(find.textContaining('\$ 10.000'), findsOneWidget);
    expect(find.textContaining('US\$ 15.26'), findsOneWidget);
    expect(find.textContaining('\$ 23.000'), findsOneWidget);

    await tester.tap(find.textContaining('US\$ 15.26'));
    expect(suggested, 23000);
  });

  testWidgets('sin datos no renderiza nada', (tester) async {
    await _pump(tester,
        const PriceReference(isFoil: false, localActiveCount: 0));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('solo local: muestra stats sin línea de mercado',
      (tester) async {
    await _pump(
        tester,
        const PriceReference(
            isFoil: false, localActiveCount: 1, localMinPrice: 5000));
    expect(find.textContaining('1 en venta'), findsOneWidget);
    expect(find.textContaining('US\$'), findsNothing);
  });

  testWidgets('mercado sin tipo de cambio: muestra USD sin ARS',
      (tester) async {
    double? suggested;
    await _pump(
        tester,
        const PriceReference(
            marketUsd: 8.5, isFoil: false, localActiveCount: 0),
        onSuggest: (v) => suggested = v);
    expect(find.textContaining('US\$ 8.50'), findsOneWidget);
    // sin ARS no hay nada para autocompletar
    await tester.tap(find.textContaining('US\$ 8.50'));
    expect(suggested, isNull);
  });

  testWidgets('si la API falla no renderiza nada', (tester) async {
    await _pump(tester, _full, fail: true);
    expect(find.byType(Text), findsNothing);
  });
}
