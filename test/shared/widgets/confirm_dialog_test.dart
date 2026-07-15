import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgmarketcordoba/shared/widgets/confirm_dialog.dart';

void main() {
  testWidgets('cancelar devuelve false y cierra el diálogo', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await confirmDestructive(
                context,
                title: 'Eliminar publicación',
                message: '¿Eliminar esta publicación? No se puede deshacer.',
              );
            },
            child: const Text('borrar'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('borrar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar publicación'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('Eliminar publicación'), findsNothing);
  });

  testWidgets('confirmar devuelve true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await confirmDestructive(
                context,
                title: 'Eliminar búsqueda',
                message: '¿Eliminar esta búsqueda? No se puede deshacer.',
              );
            },
            child: const Text('borrar'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('borrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
