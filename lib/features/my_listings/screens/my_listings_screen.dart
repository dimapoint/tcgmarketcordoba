import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../my_listings_provider.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis publicaciones'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => context.push('/profile'),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Activas'), Tab(text: 'Vendidas')],
          ),
        ),
        body: TabBarView(children: [
          _ListingsList(status: 'active'),
          _ListingsList(status: 'sold'),
        ]),
      ),
    );
  }
}

class _ListingsList extends ConsumerWidget {
  final String status;
  const _ListingsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider(status));

    return listings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) => items.isEmpty
          ? Center(
              child: Text(
                'No hay publicaciones ${status == 'active' ? 'activas' : 'vendidas'}',
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _ListingTile(listing: items[i]),
            ),
    );
  }
}

class _ListingTile extends ConsumerWidget {
  final Listing listing;
  const _ListingTile({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: ConditionBadge(condition: listing.condition),
      title: Text(listing.cardName),
      subtitle: Text('\$${listing.price.toStringAsFixed(0)} · ${listing.setName}'),
      trailing: listing.status == 'active'
          ? PopupMenuButton<String>(
              onSelected: (action) => switch (action) {
                'sold'   => ref.read(myListingsActionsProvider.notifier).markSold(listing.id),
                'remove' => ref.read(myListingsActionsProvider.notifier).remove(listing.id),
                _        => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sold',   child: Text('Marcar como vendida')),
                PopupMenuItem(value: 'remove', child: Text('Eliminar')),
              ],
            )
          : null,
    );
  }
}
