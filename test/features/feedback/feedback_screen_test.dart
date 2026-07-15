import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tcgmarketcordoba/features/feedback/feedback_repository.dart';
import 'package:tcgmarketcordoba/features/feedback/screens/feedback_screen.dart';

class _FakeFeedbackRepo implements FeedbackRepository {
  final sent = <(String, String)>[]; // (category, message)
  Object? throwOnSubmit;

  @override
  Future<void> submit(
      {required String category, required String message}) async {
    if (throwOnSubmit != null) throw throwOnSubmit!;
    sent.add((category, message));
  }
}

void main() {
  late _FakeFeedbackRepo repo;

  setUp(() => repo = _FakeFeedbackRepo());

  Widget app() {
    final router = GoRouter(initialLocation: '/feedback', routes: [
      GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/feedback', builder: (c, s) => const FeedbackScreen()),
    ]);
    return ProviderScope(
      overrides: [feedbackRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('envía categoría y mensaje y vuelve atrás', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Sugerencia'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'estaría bueno filtrar');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(repo.sent, [('sugerencia', 'estaría bueno filtrar')]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('no envía con mensaje vacío', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Enviar'));
    await tester.pump();

    expect(repo.sent, isEmpty);
    expect(find.text('Escribí un mensaje antes de enviar'), findsOneWidget);
  });

  testWidgets('muestra error si el envío falla y no navega', (tester) async {
    repo.throwOnSubmit = Exception('boom');
    await tester.pumpWidget(app());

    await tester.enterText(find.byType(TextField), 'hola');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo enviar'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });
}
