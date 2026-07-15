import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../admin_provider.dart';
import '../widgets/admin_filter_bar.dart';
import '../widgets/moderation_row.dart';

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
            loading: () => const WantedListSkeleton(),
            error: (e, _) => ErrorState(
                onRetry: () => ref.invalidate(adminBuyOrdersProvider)),
            data: (state) => state.items.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined, message: 'Sin resultados')
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminBuyOrdersProvider),
                    child: ListView.builder(
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i == state.items.length) {
                          Future.microtask(() => ref
                              .read(adminBuyOrdersProvider.notifier)
                              .loadMore());
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final order = state.items[i];
                        return ModerationRow(
                          imageUrl: order.cardImageThumb(96),
                          cardName: order.cardName,
                          condition: order.minCondition,
                          username: order.buyerUsername,
                          city: order.buyerCity,
                          price: order.maxPrice,
                          priceLabel: 'hasta',
                          createdAt: order.createdAt,
                          status: order.status,
                          onToggle: () => _confirmToggleStatus(
                              context, ref, order.id, order.status),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
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

  final confirm = await confirmDestructive(
    context,
    title: 'Quitar buscado',
    message: '¿Seguro que deseas quitar este buscado?',
    confirmLabel: 'Quitar',
  );

  if (confirm) {
    ref.read(adminActionsProvider.notifier).setBuyOrderStatus(id, 'removed');
  }
}
