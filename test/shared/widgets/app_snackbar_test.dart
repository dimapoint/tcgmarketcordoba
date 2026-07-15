import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/widgets/app_snackbar.dart';

Widget _app(void Function(BuildContext) onTap) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('success muestra texto e ícono de check', (tester) async {
    await tester.pumpWidget(_app(
      (c) => showAppSnackBar(c, '¡Publicado!', type: AppSnackBarType.success),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('¡Publicado!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('error muestra ícono de error', (tester) async {
    await tester.pumpWidget(_app(
      (c) => showAppSnackBar(c, 'Falló', type: AppSnackBarType.error),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('Falló'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('info es el default y no lleva ícono de estado', (tester) async {
    await tester.pumpWidget(_app((c) => showAppSnackBar(c, 'Dato')));
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('Dato'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
