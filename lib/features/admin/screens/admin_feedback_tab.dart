import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

class AdminFeedbackTab extends ConsumerWidget {
  const AdminFeedbackTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(adminFeedbackProvider);

    return itemsAsync.when(
      loading: () => const WantedListSkeleton(),
      error: (e, _) =>
          ErrorState(onRetry: () => ref.invalidate(adminFeedbackProvider)),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined, message: 'Sin mensajes todavía')
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              itemBuilder: (c, i) => _FeedbackRow(item: items[i]),
            ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  final FeedbackItem item;
  const _FeedbackRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          child: Icon(icon, color: fg, size: 20),
        ),
        title: Text(item.message),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${item.username} · ${relativeTime(item.createdAt)}'),
        ),
        trailing: Chip(
          label: Text(item.category),
          backgroundColor: bg,
          labelStyle: TextStyle(color: fg, fontWeight: FontWeight.bold),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
