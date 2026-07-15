import 'package:flutter/material.dart';
import '../../my_listings/screens/my_listings_tab.dart';
import '../../profile/screens/profile_tab.dart';

/// Área personal unificada: publicaciones propias ("Mis cartas") y perfil.
class AccountScreen extends StatelessWidget {
  final String? initialTab;
  const AccountScreen({super.key, this.initialTab});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == 'perfil' ? 1 : 0,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      'Mi cuenta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const TabBar(
                    tabs: [Tab(text: 'Mis cartas'), Tab(text: 'Perfil')],
                  ),
                  const Expanded(
                    child: TabBarView(children: [
                      MyListingsTab(),
                      ProfileTab(),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
