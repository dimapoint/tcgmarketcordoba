import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/models/wanted_order.dart';
import '../../auth/auth_provider.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isAdmin = session?.user.isAdmin ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: isAdmin
              ? const TabBar(tabs: [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Publicaciones'),
                  Tab(text: 'Buscados'),
                ])
              : null,
        ),
        body: isAdmin
            ? const TabBarView(children: [
                _SummaryTab(),
                _ListingsTab(),
                _BuyOrdersTab(),
              ])
            : const Center(child: Text('Solo para administradores')),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

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
                  onPressed: (syncAsync.valueOrNull?.isRunning ?? false) ||
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
                      Icon(t.$3, size: 28, color: Theme.of(context).colorScheme.primary),
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

const _statusFilters = [
  ('', 'Todas'),
  ('active', 'Activas'),
  ('removed', 'Eliminadas'),
];

class _ListingsTab extends ConsumerWidget {
  const _ListingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminListingsFilterProvider);
    final itemsAsync = ref.watch(adminListingsProvider);

    return Column(
      children: [
        _FilterBar(
          status: filter.status,
          statusOptions: const [..._statusFilters, ('sold', 'Vendidas')],
          onStatusChanged: (s) => ref
              .read(adminListingsFilterProvider.notifier)
              .update((f) => (status: s, query: f.query)),
          onQueryChanged: (q) => ref
              .read(adminListingsFilterProvider.notifier)
              .update((f) => (status: f.status, query: q)),
        ),
        Expanded(
          child: itemsAsync.when(
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
                        const Text('Sin resultados', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) =>
                        _ListingRow(listing: items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ListingRow extends ConsumerWidget {
  final Listing listing;
  const _ListingRow({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRemoved = listing.status == 'removed';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.style)),
      title: Text(listing.cardName),
      subtitle:
          Text('${listing.sellerUsername} · \$${listing.price.toStringAsFixed(0)}'),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildStatusChip(context, listing.status),
          TextButton(
            onPressed: () => _confirmToggleStatus(
                context, ref, listing.id, listing.status, true),
            child: Text(isRemoved ? 'Restaurar' : 'Quitar'),
          ),
        ],
      ),
    );
  }
}

class _BuyOrdersTab extends ConsumerWidget {
  const _BuyOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminBuyOrdersFilterProvider);
    final itemsAsync = ref.watch(adminBuyOrdersProvider);

    return Column(
      children: [
        _FilterBar(
          status: filter.status,
          statusOptions: const [..._statusFilters, ('fulfilled', 'Cumplidas')],
          onStatusChanged: (s) => ref
              .read(adminBuyOrdersFilterProvider.notifier)
              .update((f) => (status: s, query: f.query)),
          onQueryChanged: (q) => ref
              .read(adminBuyOrdersFilterProvider.notifier)
              .update((f) => (status: f.status, query: q)),
        ),
        Expanded(
          child: itemsAsync.when(
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
                        const Text('Sin resultados', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (c, i) =>
                        _BuyOrderRow(order: items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _BuyOrderRow extends ConsumerWidget {
  final WantedOrder order;
  const _BuyOrderRow({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRemoved = order.status == 'removed';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.manage_search)),
      title: Text(order.cardName),
      subtitle: Text(
          '${order.buyerUsername} · hasta \$${order.maxPrice.toStringAsFixed(0)}'),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildStatusChip(context, order.status),
          TextButton(
            onPressed: () => _confirmToggleStatus(
                context, ref, order.id, order.status, false),
            child: Text(isRemoved ? 'Restaurar' : 'Quitar'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  final String status;
  final List<(String, String)> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  const _FilterBar({
    required this.status,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: widget.statusOptions
                .map((o) => ChoiceChip(
                      label: Text(o.$2),
                      selected: widget.status == o.$1,
                      onSelected: (_) => widget.onStatusChanged(o.$1),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  widget.onQueryChanged('');
                },
              ),
              hintText: 'Buscar por carta o usuario',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: widget.onQueryChanged,
          ),
        ],
      ),
    );
  }
}

Widget _buildStatusChip(BuildContext context, String status) {
  final (Color bg, Color fg) = switch (status) {
    'active' => (Colors.green.shade100, Colors.green.shade900),
    'removed' => (Colors.red.shade100, Colors.red.shade900),
    'sold' || 'fulfilled' => (Colors.blue.shade100, Colors.blue.shade900),
    _ => (Colors.grey.shade200, Colors.grey.shade800),
  };

  return Chip(
    label: Text(status),
    backgroundColor: bg,
    labelStyle: TextStyle(color: fg, fontWeight: FontWeight.bold),
    side: BorderSide.none,
  );
}

Future<void> _confirmToggleStatus(
  BuildContext context,
  WidgetRef ref,
  String id,
  String currentStatus,
  bool isListing,
) async {
  final isRemoved = currentStatus == 'removed';
  if (isRemoved) {
    if (isListing) {
      ref.read(adminActionsProvider.notifier).setListingStatus(id, 'active');
    } else {
      ref.read(adminActionsProvider.notifier).setBuyOrderStatus(id, 'active');
    }
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Confirmar acción'),
      content: Text(isListing
          ? '¿Seguro que deseas quitar esta publicación?'
          : '¿Seguro que deseas quitar este buscado?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Quitar'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    if (isListing) {
      ref.read(adminActionsProvider.notifier).setListingStatus(id, 'removed');
    } else {
      ref.read(adminActionsProvider.notifier).setBuyOrderStatus(id, 'removed');
    }
  }
}
