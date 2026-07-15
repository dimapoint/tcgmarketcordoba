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

class AdminListingsTab extends ConsumerWidget {
  const AdminListingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminListingsFilterProvider);
    final itemsAsync = ref.watch(adminListingsProvider);

    return Column(
      children: [
        AdminFilterBar(
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
            loading: () => const WantedListSkeleton(),
            error: (e, _) =>
                ErrorState(onRetry: () => ref.invalidate(adminListingsProvider)),
            data: (state) => state.items.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined, message: 'Sin resultados')
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminListingsProvider),
                    child: ListView.builder(
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i == state.items.length) {
                          Future.microtask(() =>
                              ref.read(adminListingsProvider.notifier).loadMore());
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final listing = state.items[i];
                        return ModerationRow(
                          imageUrl: listing.cardImageThumb(96),
                          cardName: listing.cardName,
                          condition: listing.condition,
                          username: listing.sellerUsername,
                          city: listing.sellerCity,
                          price: listing.price,
                          createdAt: listing.createdAt,
                          status: listing.status,
                          onToggle: () => _confirmToggleStatus(
                              context, ref, listing.id, listing.status),
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
    ref.read(adminActionsProvider.notifier).setListingStatus(id, 'active');
    return;
  }

  final confirm = await confirmDestructive(
    context,
    title: 'Quitar publicación',
    message: '¿Seguro que deseas quitar esta publicación?',
    confirmLabel: 'Quitar',
  );

  if (confirm) {
    ref.read(adminActionsProvider.notifier).setListingStatus(id, 'removed');
  }
}
