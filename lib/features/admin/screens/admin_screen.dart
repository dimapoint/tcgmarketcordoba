import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import 'admin_buy_orders_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_listings_tab.dart';
import 'admin_summary_tab.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).value;
    final isAdmin = session?.user.isAdmin ?? false;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          bottom: isAdmin
              ? const TabBar(tabs: [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Publicaciones'),
                  Tab(text: 'Buscados'),
                  Tab(text: 'Feedback'),
                ])
              : null,
        ),
        body: isAdmin
            ? const TabBarView(children: [
                AdminSummaryTab(),
                AdminListingsTab(),
                AdminBuyOrdersTab(),
                AdminFeedbackTab(),
              ])
            : const Center(child: Text('Solo para administradores')),
      ),
    );
  }
}
