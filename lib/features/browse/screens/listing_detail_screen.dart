import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/listing.dart';
import '../../../shared/share/share.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/photo_carousel.dart';
import '../../../shared/widgets/price_text.dart';
import '../listing_provider.dart';

class ListingDetailScreen extends ConsumerWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailProvider(id));
    final session = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (listingAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir',
              onPressed: () {
                final l = listingAsync.value!;
                final url = '${currentOrigin()}/l/${l.id}';
                shareWithFallback(
                  context,
                  text: listingShareText(l, url),
                  url: url,
                );
              },
            ),
        ],
      ),
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
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    final photos = PhotoCarousel(photos: listing.photos);
    final info = _Info(listing: listing, isLoggedIn: isLoggedIn);

    return SingleChildScrollView(
      child: CenteredMaxWidth(
        maxWidth: 1000,
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24 : 0),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 420,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: photos,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(child: info),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    photos,
                    Padding(padding: const EdgeInsets.all(16), child: info),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final Listing listing;
  final bool isLoggedIn;
  const _Info({required this.listing, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          listing.cardName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoChip(label: listing.setName, icon: Icons.collections_bookmark_outlined),
            if (listing.isFoil)
              _InfoChip(
                label: '✦ Foil',
                icon: null,
                color: AppColors.price(context),
              ),
            ConditionBadge(condition: listing.condition),
          ],
        ),
        const SizedBox(height: 16),
        PriceText(price: listing.price, fontSize: 32),
        if (listing.description != null &&
            listing.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                listing.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    listing.sellerUsername.isNotEmpty
                        ? listing.sellerUsername[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.sellerUsername,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            listing.sellerCity,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Contactar al vendedor',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _ContactSection(sellerId: listing.sellerId, isLoggedIn: isLoggedIn),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _InfoChip({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
          color: color?.withValues(alpha: 0.6) ?? scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends ConsumerWidget {
  final String sellerId;
  final bool isLoggedIn;
  const _ContactSection({required this.sellerId, required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLoggedIn) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => context.push('/sign-in'),
          icon: const Icon(Icons.login),
          label: const Text('Iniciá sesión para contactar'),
        ),
      );
    }

    final contactsAsync = ref.watch(sellerContactsProvider(sellerId));

    return contactsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (contacts) => contacts.isEmpty
          ? Text(
              'El vendedor no cargó métodos de contacto.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: contacts.map((c) => _ContactButton(method: c)).toList(),
            ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final Map<String, dynamic> method;
  const _ContactButton({required this.method});

  @override
  Widget build(BuildContext context) {
    final type = method['type'] as String;
    final value = method['value'] as String;

    final (icon, label, url, color) = switch (type) {
      'whatsapp' => (
          Icons.chat,
          'WhatsApp · $value',
          'https://wa.me/$value',
          const Color(0xFF25D366),
        ),
      'instagram' => (
          Icons.camera_alt,
          'Instagram · $value',
          'https://instagram.com/$value',
          const Color(0xFFE1306C),
        ),
      'telegram' => (
          Icons.send,
          'Telegram · $value',
          'https://t.me/$value',
          const Color(0xFF229ED9),
        ),
      'email' => (
          Icons.email,
          'Email · $value',
          'mailto:$value',
          Theme.of(context).colorScheme.primary,
        ),
      _ => (
          Icons.contact_page,
          value,
          '',
          Theme.of(context).colorScheme.primary,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: url.isEmpty ? null : () => launchUrl(Uri.parse(url)),
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
