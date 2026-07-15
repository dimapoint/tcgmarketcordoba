import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../feedback_repository.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _messageCtrl = TextEditingController();
  String _category = 'bug';
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      showAppSnackBar(context, 'Escribí un mensaje antes de enviar',
          type: AppSnackBarType.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .submit(category: _category, message: message);
      if (!mounted) return;
      showAppSnackBar(context, '¡Gracias! Recibimos tu mensaje.',
          type: AppSnackBarType.success);
      // Deep link directo a /feedback: no hay stack para volver.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, 'No se pudo enviar: $e',
          type: AppSnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar un problema')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Contanos qué pasó o qué te gustaría mejorar. '
                  'Leemos todos los mensajes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'bug',
                        label: Text('Bug'),
                        icon: Icon(Icons.bug_report_outlined)),
                    ButtonSegment(
                        value: 'sugerencia',
                        label: Text('Sugerencia'),
                        icon: Icon(Icons.lightbulb_outline)),
                    ButtonSegment(
                        value: 'otro',
                        label: Text('Otro'),
                        icon: Icon(Icons.chat_bubble_outline)),
                  ],
                  selected: {_category},
                  onSelectionChanged: (s) =>
                      setState(() => _category = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    hintText:
                        'Describí el problema o tu sugerencia con detalle',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Enviar'),
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
