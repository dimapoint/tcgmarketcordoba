import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/max_width.dart';
import '../../auth/auth_provider.dart';
import 'admin_buy_orders_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_listings_tab.dart';
import 'admin_summary_tab.dart';
import 'admin_users_tab.dart';

const _sections = [
  (label: 'Resumen', icon: Icons.dashboard_outlined, body: AdminSummaryTab()),
  (label: 'Usuarios', icon: Icons.people_outline, body: AdminUsersTab()),
  (label: 'Publicaciones', icon: Icons.storefront_outlined, body: AdminListingsTab()),
  (label: 'Buscados', icon: Icons.manage_search_outlined, body: AdminBuyOrdersTab()),
  (label: 'Feedback', icon: Icons.chat_bubble_outline, body: AdminFeedbackTab()),
];

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).value;
    final isAdmin = session?.user.isAdmin ?? false;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración')),
        body: const Center(child: Text('Solo para administradores')),
      );
    }

    final isWide =
        MediaQuery.sizeOf(context).width >= AppTheme.mobileBreakpoint;

    return DefaultTabController(
      length: _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: isWide
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs: [for (final s in _sections) Tab(text: s.label)],
                ),
        ),
        body: isWide ? const _WideBody() : const _NarrowBody(),
      ),
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody();

  @override
  Widget build(BuildContext context) {
    return TabBarView(children: [for (final s in _sections) s.body]);
  }
}

class _WideBody extends StatefulWidget {
  const _WideBody();

  @override
  State<_WideBody> createState() => _WideBodyState();
}

class _WideBodyState extends State<_WideBody> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final s in _sections)
              NavigationRailDestination(
                icon: Icon(s.icon),
                label: Text(s.label),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: CenteredMaxWidth(child: _sections[_index].body),
        ),
      ],
    );
  }
}
