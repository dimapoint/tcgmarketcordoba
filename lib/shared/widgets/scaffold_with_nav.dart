import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../features/matches/matches_provider.dart';

/// Shell adaptativo: bottom nav en móvil, header de marketplace en pantallas
/// anchas (>= [AppTheme.mobileBreakpoint]).
class ScaffoldWithNav extends ConsumerWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static const _destinations = [
    (path: '/', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Explorar'),
    (path: '/wanted', icon: Icons.travel_explore_outlined, selectedIcon: Icons.travel_explore, label: 'Busco'),
    (path: '/post', icon: Icons.add_circle_outline, selectedIcon: Icons.add_circle, label: 'Publicar'),
    (path: '/my-listings', icon: Icons.style_outlined, selectedIcon: Icons.style, label: 'Mis Cartas'),
    (path: '/profile', icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
  ];

  static int _indexOf(String location) => switch (location) {
        String l when l.startsWith('/wanted') => 1, // cubre /wanted y /wanted/new
        String l when l.startsWith('/post') => 2,
        String l when l.startsWith('/my-listings') => 3,
        String l when l.startsWith('/profile') => 4,
        _ => 0,
      };

  /// Badge de novedades solo sobre "Busco"; el resto de los ítems no
  /// notifican nada.
  static Widget _navIcon(IconData icon, String path, int unseen) {
    final base = Icon(icon);
    if (path != '/wanted' || unseen == 0) return base;
    return Badge.count(count: unseen, child: base);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(location);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;
    final unseen = ref.watch(unseenMatchesProvider).valueOrNull ?? 0;

    if (isWide) {
      return Scaffold(
        body: Column(
          children: [
            _TopHeader(selectedIndex: index, unseenMatches: unseen),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: _navIcon(d.icon, d.path, unseen),
              selectedIcon: _navIcon(d.selectedIcon, d.path, unseen),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final int selectedIndex;
  final int unseenMatches;
  const _TopHeader({required this.selectedIndex, required this.unseenMatches});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        height: 64,
        child: Row(
          children: [
            const Wordmark(),
            const SizedBox(width: 32),
            // Scrolleable para que el header no desborde en anchos apenas
            // mayores al breakpoint (700-750px).
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, d)
                        in ScaffoldWithNav._destinations.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _NavButton(
                          label: d.label,
                          icon: selectedIndex == i ? d.selectedIcon : d.icon,
                          selected: selectedIndex == i,
                          badgeCount: d.path == '/wanted' ? unseenMatches : 0,
                          onTap: () => context.go(d.path),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final iconWidget = Icon(icon, size: 20, color: color);

    return TextButton.icon(
      onPressed: onTap,
      icon: badgeCount > 0
          ? Badge.count(count: badgeCount, child: iconWidget)
          : iconWidget,
      label: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
      style: TextButton.styleFrom(
        backgroundColor:
            selected ? scheme.primary.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

/// Wordmark de la marca: "TCGMarket" + "Córdoba" en dorado.
class Wordmark extends StatelessWidget {
  final double fontSize;
  const Wordmark({super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'TCGMarket ', style: base),
        TextSpan(
          text: 'Córdoba',
          style: base.copyWith(color: AppColors.price(context)),
        ),
      ]),
    );
  }
}
