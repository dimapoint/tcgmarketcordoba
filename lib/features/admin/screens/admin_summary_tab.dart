import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

class AdminSummaryTab extends ConsumerWidget {
  const AdminSummaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final syncAsync = ref.watch(syncStatusProvider);
    final actions = ref.watch(adminActionsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (stats) => _StatsGrid(stats: stats),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Catálogo de cartas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                syncAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (status) => _SyncCard(status: status),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar cartas'),
                  onPressed: (syncAsync.value?.isRunning ?? false) ||
                          actions.isLoading
                      ? null
                      : () => ref
                          .read(adminActionsProvider.notifier)
                          .startSync(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AdminStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Usuarios', stats.users, Icons.people),
      ('Publicaciones activas', stats.activeListings, Icons.storefront),
      ('Buscados activos', stats.activeBuyOrders, Icons.manage_search),
      ('Usuarios (7d)', stats.newUsers7d, Icons.person_add),
      ('Publicaciones (7d)', stats.newListings7d, Icons.add_business),
      ('Buscados (7d)', stats.newBuyOrders7d, Icons.search),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: tiles
          .map((t) => Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.$3,
                          size: 28, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('${t.$2}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              )),
                      const SizedBox(height: 4),
                      Text(t.$1,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _SyncCard extends StatelessWidget {
  final SyncStatus status;
  const _SyncCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status.status) {
      'running' => const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Sincronizando...'),
        ]),
      'ok' => Text(
          'Última sincronización OK: ${status.summary?.sets ?? 0} sets, '
          '${status.summary?.cards ?? 0} cartas '
          '(${status.summary?.newCards ?? 0} nuevas)',
        ),
      'error' => Text('Último intento falló: ${status.error}',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      _ => const Text('Sin sincronizaciones todavía'),
    };
  }
}
