import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/browse/listing_provider.dart' show sellerContactsProvider;
import '../../../shared/models/wanted_order.dart';
import '../../../shared/share/share.dart';
import '../../../shared/widgets/condition_badge.dart';
import '../../../shared/widgets/max_width.dart';
import '../../../shared/widgets/price_text.dart';
import '../wanted_provider.dart';

class WantedDetailScreen extends ConsumerWidget {
  final String id;
  const WantedDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(wantedDetailProvider(id));
    final session = ref.watch(authSessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (orderAsync.value != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartir',
              onPressed: () {
                final o = orderAsync.value!;
                final url = '${currentOrigin()}/b/${o.id}';
                shareWithFallback(
                  context,
                  text: wantedShareText(o, url),
                  url: url,
                );
              },
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) => _Body(order: order, isLoggedIn: session != null),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final WantedOrder order;
  final bool isLoggedIn;
  const _Body({required this.order, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;
    final image = order.cardImageThumb(400);

    final info = _Info(order: order, isLoggedIn: isLoggedIn);
    final card = image == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: image, width: 220),
          );

    return SingleChildScrollView(
      child: CenteredMaxWidth(
        maxWidth: 700,
        child: Padding(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: card == null
              ? info
              : isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        card,
                        const SizedBox(width: 24),
                        Expanded(child: info),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: card),
                        const SizedBox(height: 16),
                        info,
                      ],
                    ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final WantedOrder order;
  final bool isLoggedIn;
  const _Info({required this.order, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.cardName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoChip(label: order.setName, icon: Icons.collections_bookmark_outlined),
            if (order.isFoil)
              _InfoChip(
                label: '✦ Foil',
                icon: null,
                color: AppColors.price(context),
              ),
            order.minCondition != null
                ? ConditionBadge(condition: order.minCondition!)
                : _InfoChip(label: 'Cualquier condición', icon: null),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Pago hasta ', style: Theme.of(context).textTheme.titleMedium),
            PriceText(price: order.maxPrice, fontSize: 32),
          ],
        ),
        Text(
          'Busco ${order.quantity}x',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (order.description != null &&
            order.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                order.description!,
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
                    order.buyerUsername.isNotEmpty
                        ? order.buyerUsername[0].toUpperCase()
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
                        order.buyerUsername,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            order.buyerCity,
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
        Text('Contactar al comprador',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _ContactSection(buyerId: order.buyerId, isLoggedIn: isLoggedIn),
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
  final String buyerId;
  final bool isLoggedIn;
  const _ContactSection({required this.buyerId, required this.isLoggedIn});

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

    final contactsAsync = ref.watch(sellerContactsProvider(buyerId));

    return contactsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (contacts) => contacts.isEmpty
          ? Text(
              'El comprador no cargó métodos de contacto.',
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
