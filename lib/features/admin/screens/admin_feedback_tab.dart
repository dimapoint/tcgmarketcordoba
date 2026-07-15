import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

const _statusFilters = [
  ('nuevo', 'Nuevos'),
  ('resuelto', 'Resueltos'),
  ('', 'Todos'),
];

class AdminFeedbackTab extends ConsumerWidget {
  const AdminFeedbackTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminFeedbackFilterProvider);
    final itemsAsync = ref.watch(adminFeedbackProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: _statusFilters
                .map((o) => ChoiceChip(
                      label: Text(o.$2),
                      selected: filter == o.$1,
                      onSelected: (_) => ref
                          .read(adminFeedbackFilterProvider.notifier)
                          .set(o.$1),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            loading: () => const WantedListSkeleton(),
            error: (e, _) =>
                ErrorState(onRetry: () => ref.invalidate(adminFeedbackProvider)),
            data: (items) => items.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined, message: 'Sin mensajes')
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    itemBuilder: (c, i) => _FeedbackRow(item: items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackRow extends ConsumerWidget {
  final FeedbackItem item;
  const _FeedbackRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = item.status == 'resuelto';
    final (Color bg, Color fg, IconData icon) = switch (item.category) {
      'bug' => (scheme.errorContainer, scheme.onErrorContainer, Icons.bug_report),
      'sugerencia' => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.lightbulb
        ),
      _ => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.chat_bubble
        ),
    };

    return Opacity(
      opacity: resolved ? 0.6 : 1,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: bg,
            child: Icon(icon, color: fg, size: 20),
          ),
          title: Text(item.message),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${item.username} · ${relativeTime(item.createdAt)}'
                '${resolved ? ' · Resuelto' : ''}'),
          ),
          trailing: Wrap(
            spacing: 0,
            children: [
              IconButton(
                icon: Icon(resolved ? Icons.replay : Icons.check_circle_outline),
                tooltip: resolved ? 'Reabrir' : 'Marcar resuelto',
                onPressed: () => ref
                    .read(adminActionsProvider.notifier)
                    .setFeedbackStatus(item.id, resolved ? 'nuevo' : 'resuelto'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                onPressed: () => _confirmDelete(context, ref, item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, FeedbackItem item) async {
  final confirm = await confirmDestructive(
    context,
    title: 'Eliminar mensaje',
    message: '¿Seguro que deseas eliminar este mensaje de feedback?',
    confirmLabel: 'Eliminar',
  );
  if (confirm) {
    ref.read(adminActionsProvider.notifier).deleteFeedback(item.id);
  }
}
