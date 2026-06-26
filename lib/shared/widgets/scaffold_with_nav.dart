import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      String l when l.startsWith('/post')        => 1,
      String l when l.startsWith('/my-listings') => 2,
      _                                          => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => switch (i) {
          0 => context.go('/'),
          1 => context.go('/post'),
          2 => context.go('/my-listings'),
          _ => null,
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search),     label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_circle), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.list),       label: 'Mis Cartas'),
        ],
      ),
    );
  }
}
