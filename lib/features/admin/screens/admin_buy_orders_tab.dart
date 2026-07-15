import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/wanted_order.dart';
import '../admin_provider.dart';
import '../widgets/admin_filter_bar.dart';
import '../widgets/status_badge.dart';

const _statusFilters = [
  ('', 'Todas'),
  ('active', 'Activas'),
  ('removed', 'Eliminadas'),
];

class AdminBuyOrdersTab extends ConsumerWidget {
  const AdminBuyOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminBuyOrdersFilterProvider);
    final itemsAsync = ref.watch(adminBuyOrdersProvider);

    return Column(
      children: [
        AdminFilterBar(
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
            data: (state) => state.items.isEmpty
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
                    itemCount:
                        state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == state.items.length) {
                        Future.microtask(() =>
                            ref.read(adminBuyOrdersProvider.notifier).loadMore());
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _BuyOrderRow(order: state.items[i]);
                    },
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
          StatusBadge(status: order.status),
          TextButton(
            onPressed: () =>
                _confirmToggleStatus(context, ref, order.id, order.status),
            child: Text(isRemoved ? 'Restaurar' : 'Quitar'),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmToggleStatus(
  BuildContext context,
  WidgetRef ref,
  String id,
  String currentStatus,
) async {
  final isRemoved = currentStatus == 'removed';
  if (isRemoved) {
    ref.read(adminActionsProvider.notifier).setBuyOrderStatus(id, 'active');
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Confirmar acción'),
      content: const Text('¿Seguro que deseas quitar este buscado?'),
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
    ref.read(adminActionsProvider.notifier).setBuyOrderStatus(id, 'removed');
  }
}
