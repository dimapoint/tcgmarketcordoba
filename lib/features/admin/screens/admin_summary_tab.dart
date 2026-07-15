import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/widgets/error_state.dart';
import '../admin_models.dart';
import '../admin_provider.dart';
import '../widgets/admin_stat_card.dart';

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
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator())),
          error: (e, _) =>
              ErrorState(onRetry: () => ref.invalidate(adminStatsProvider)),
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
                  error: (e, _) =>
                      ErrorState(onRetry: () => ref.invalidate(syncStatusProvider)),
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
      ('Usuarios', stats.users, stats.newUsers7d, Icons.people),
      ('Publicaciones activas', stats.activeListings, stats.newListings7d,
          Icons.storefront),
      ('Buscados activos', stats.activeBuyOrders, stats.newBuyOrders7d,
          Icons.manage_search),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 170,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final t = tiles[i];
        return AdminStatCard(
            label: t.$1, value: t.$2, delta7d: t.$3, icon: t.$4);
      },
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
          'Última sincronización OK ${status.finishedAt != null ? relativeTime(status.finishedAt!) : ''}: '
          '${status.summary?.sets ?? 0} sets, '
          '${status.summary?.cards ?? 0} cartas '
          '(${status.summary?.newCards ?? 0} nuevas)',
        ),
      'error' => Text('Último intento falló: ${status.error}',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      _ => const Text('Sin sincronizaciones todavía'),
    };
  }
}
