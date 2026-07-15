import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

class AdminFeedbackTab extends ConsumerWidget {
  const AdminFeedbackTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(adminFeedbackProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Sin mensajes todavía',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            )
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
    final (Color bg, Color fg, IconData icon) = switch (item.category) {
      'bug' => (Colors.red.shade100, Colors.red.shade900, Icons.bug_report),
      'sugerencia' => (
          Colors.amber.shade100,
          Colors.amber.shade900,
          Icons.lightbulb
        ),
      _ => (Colors.grey.shade200, Colors.grey.shade800, Icons.chat_bubble),
    };
    final d = item.createdAt.toLocal();
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          child: Icon(icon, color: fg, size: 20),
        ),
        title: Text(item.message),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${item.username} · $date'),
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
