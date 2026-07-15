import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/widgets/error_state.dart';

void main() {
  testWidgets('muestra mensaje amigable y botón Reintentar', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(onRetry: () => retried = true),
      ),
    ));

    expect(find.text('No pudimos cargar los datos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);
  });

  testWidgets('acepta mensaje custom y oculta botón sin onRetry',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ErrorState(message: 'Se rompió todo')),
    ));

    expect(find.text('Se rompió todo'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
}
