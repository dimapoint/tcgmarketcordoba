import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/format/relative_time.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/auth_provider.dart';
import '../admin_models.dart';
import '../admin_provider.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(adminUsersProvider);
    final myId = ref.watch(authSessionProvider).value?.user.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  ref.read(adminUsersQueryProvider.notifier).set('');
                },
              ),
              hintText: 'Buscar por email o usuario',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (q) =>
                ref.read(adminUsersQueryProvider.notifier).set(q),
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            loading: () => const WantedListSkeleton(),
            error: (e, _) =>
                ErrorState(onRetry: () => ref.invalidate(adminUsersProvider)),
            data: (state) => state.items.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline, message: 'Sin resultados')
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminUsersProvider),
                    child: ListView.builder(
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i == state.items.length) {
                          Future.microtask(() =>
                              ref.read(adminUsersProvider.notifier).loadMore());
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final user = state.items[i];
                        return _UserRow(user: user, isSelf: user.id == myId);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends ConsumerWidget {
  final AdminUser user;
  final bool isSelf;
  const _UserRow({required this.user, required this.isSelf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.username.isNotEmpty
              ? user.username[0].toUpperCase()
              : '?'),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(user.username, overflow: TextOverflow.ellipsis),
            ),
            if (user.isAdmin) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Admin'),
                backgroundColor: scheme.primaryContainer,
                labelStyle: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${user.email}\n${user.city ?? 'sin ciudad'} · '
          '${user.activeListings} publicaciones · ${user.activeBuyOrders} buscados · '
          '${relativeTime(user.createdAt)}',
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: isSelf
              ? null
              : () => _confirmToggleAdmin(context, ref, user),
          child: Text(user.isAdmin ? 'Quitar admin' : 'Hacer admin'),
        ),
      ),
    );
  }
}

Future<void> _confirmToggleAdmin(
    BuildContext context, WidgetRef ref, AdminUser user) async {
  final makeAdmin = !user.isAdmin;
  final confirm = await confirmDestructive(
    context,
    title: 'Cambiar rol',
    message: makeAdmin
        ? '¿Convertir a "${user.username}" en administrador?'
        : '¿Quitarle el rol de administrador a "${user.username}"?',
    confirmLabel: 'Confirmar',
  );
  if (confirm) {
    ref.read(adminActionsProvider.notifier).setUserAdmin(user.id, makeAdmin);
  }
}
