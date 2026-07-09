import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/features/post_listing/card_repository.dart';
import 'package:tcgmarketcordoba/features/post_wanted/post_wanted_provider.dart';
import 'package:tcgmarketcordoba/features/post_wanted/screens/post_wanted_screen.dart';
import 'package:tcgmarketcordoba/shared/models/card_printing.dart';
import 'package:tcgmarketcordoba/shared/models/price_reference.dart';

class _FakeCardRepository implements CardRepository {
  @override
  Future<PriceReference> priceReference(String printingId) async =>
      const PriceReference(
        marketUsd: 15.26,
        marketArs: 23000,
        fxRate: 1510,
        isFoil: false,
        localActiveCount: 2,
        localMinPrice: 10000,
      );

  @override
  Future<List<CardPrinting>> search(String query) async {
    if (query.toLowerCase().contains('jinx')) {
      return const [
        CardPrinting(
          id: 'cp-1',
          cardId: 'c-1',
          cardName: 'Jinx',
          setName: 'Origins',
          setCode: 'OGN',
          cardNumber: '001',
          isFoil: false,
        ),
      ];
    }
    return const [];
  }
}

ProviderContainer _container() => ProviderContainer(overrides: [
      cardRepositoryProvider.overrideWithValue(_FakeCardRepository()),
    ]);

Widget _harness(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('initialQuery prefilla el buscador y dispara la búsqueda',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(container, const PostWantedScreen(initialQuery: 'jinx')),
    );
    await tester.pumpAndSettle();

    // El SearchBar muestra el texto prefillado.
    expect(find.widgetWithText(SearchBar, 'jinx'), findsOneWidget);
    // Y los resultados del catálogo ya están cargados sin re-escribir.
    expect(find.text('Jinx'), findsOneWidget);
    expect(container.read(wantedCardSearchQueryProvider), 'jinx');
  });

  testWidgets('sin initialQuery el buscador arranca limpio aunque el provider '
      'tenga texto viejo', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    // Texto residual de una visita anterior (el provider no es autoDispose).
    container.read(wantedCardSearchQueryProvider.notifier).state = 'viejo';

    await tester.pumpWidget(_harness(container, const PostWantedScreen()));
    await tester.pumpAndSettle();

    expect(container.read(wantedCardSearchQueryProvider), '');
    expect(find.widgetWithText(SearchBar, 'viejo'), findsNothing);
  });

  testWidgets('al elegir carta el paso 2 muestra la referencia de precio '
      'y el tap autocompleta "Pago hasta"', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _harness(container, const PostWantedScreen(initialQuery: 'jinx')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jinx'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 en venta acá'), findsOneWidget);
    expect(find.textContaining('US\$ 15.26'), findsOneWidget);

    await tester.tap(find.textContaining('US\$ 15.26'));
    await tester.pump();

    expect(find.widgetWithText(TextField, '23000'), findsOneWidget);
    expect(container.read(postWantedFormProvider).maxPrice, 23000);
  });
}
