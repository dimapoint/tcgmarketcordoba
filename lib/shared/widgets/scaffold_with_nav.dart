import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Shell adaptativo: bottom nav en móvil, header de marketplace en pantallas
/// anchas (>= [AppTheme.mobileBreakpoint]).
class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static const _destinations = [
    (path: '/', icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Explorar'),
    (path: '/post', icon: Icons.add_circle_outline, selectedIcon: Icons.add_circle, label: 'Publicar'),
    (path: '/my-listings', icon: Icons.style_outlined, selectedIcon: Icons.style, label: 'Mis Cartas'),
    (path: '/profile', icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil'),
  ];

  static int _indexOf(String location) => switch (location) {
        String l when l.startsWith('/post') => 1,
        String l when l.startsWith('/my-listings') => 2,
        String l when l.startsWith('/profile') => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(location);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Column(
          children: [
            _TopHeader(selectedIndex: index),
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
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final int selectedIndex;
  const _TopHeader({required this.selectedIndex});

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
  final VoidCallback onTap;
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
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
