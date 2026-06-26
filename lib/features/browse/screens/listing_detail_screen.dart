import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/photo_carousel.dart';
import '../listing_provider.dart';

class ListingDetailScreen extends ConsumerWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailProvider(id));
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (listing) => _Body(listing: listing, isLoggedIn: session != null),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Listing listing;
  final bool isLoggedIn;
  const _Body({required this.listing, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoCarousel(photos: listing.photos),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.cardName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${listing.setName}${listing.isFoil ? ' · Foil' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ConditionBadge(condition: listing.condition),
                    const SizedBox(width: 12),
                    Text(
                      '\$${listing.price.toStringAsFixed(0)} ARS',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                if (listing.description != null) ...[
                  const SizedBox(height: 12),
                  Text(listing.description!),
                ],
                const Divider(height: 32),
                Text('Vendedor: ${listing.sellerUsername}'),
                Text('Ciudad: ${listing.sellerCity}'),
                const SizedBox(height: 24),
                _ContactButton(
                  sellerId: listing.sellerId,
                  isLoggedIn: isLoggedIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends ConsumerWidget {
  final String sellerId;
  final bool isLoggedIn;
  const _ContactButton({required this.sellerId, required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLoggedIn) {
      return FilledButton.icon(
        onPressed: () => context.push('/sign-in'),
        icon: const Icon(Icons.login),
        label: const Text('Iniciá sesión para contactar'),
      );
    }

    final contactsAsync = ref.watch(sellerContactsProvider(sellerId));

    return contactsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data:
          (contacts) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contacts.map((c) => _ContactChip(method: c)).toList(),
          ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final Map<String, dynamic> method;
  const _ContactChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final type = method['type'] as String;
    final value = method['value'] as String;

    final (icon, label, url) = switch (type) {
      'whatsapp' => (
        Icons.chat,
        'WhatsApp: $value',
        'https://wa.me/$value',
      ),
      'instagram' => (
        Icons.camera_alt,
        'Instagram: $value',
        'https://instagram.com/$value',
      ),
      'telegram' => (
        Icons.send,
        'Telegram: $value',
        'https://t.me/$value',
      ),
      'email' => (Icons.email, 'Email: $value', 'mailto:$value'),
      _ => (Icons.contact_page, value, ''),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: url.isEmpty ? null : () => launchUrl(Uri.parse(url)),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
