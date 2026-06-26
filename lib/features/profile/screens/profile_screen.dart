import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/profile.dart';
import '../profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final contactsAsync = ref.watch(contactMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authActionsProvider.notifier).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => profile == null
            ? const SizedBox()
            : _ProfileBody(
                profile: profile,
                contactsAsync: contactsAsync,
              ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final Profile profile;
  final AsyncValue<List<ContactMethod>> contactsAsync;
  const _ProfileBody({required this.profile, required this.contactsAsync});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile.username);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Usuario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => ref
                  .read(profileActionsProvider.notifier)
                  .updateUsername(_usernameCtrl.text.trim()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Métodos de contacto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        widget.contactsAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (contacts) => Column(
            children: [
              ...contacts.map(
                (c) => ListTile(
                  leading: const Icon(Icons.contact_page),
                  title: Text('${c.type}: ${c.value}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => ref
                        .read(profileActionsProvider.notifier)
                        .deleteContact(c.id),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddContactDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Agregar contacto'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddContactDialog(BuildContext context) {
    String type = 'whatsapp';
    final valueCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'whatsapp',
                    child: Text('WhatsApp'),
                  ),
                  DropdownMenuItem(
                    value: 'instagram',
                    child: Text('Instagram'),
                  ),
                  DropdownMenuItem(
                    value: 'email',
                    child: Text('Email'),
                  ),
                  DropdownMenuItem(
                    value: 'telegram',
                    child: Text('Telegram'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueCtrl,
                decoration: const InputDecoration(
                  hintText: 'Valor (número, usuario, etc.)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(profileActionsProvider.notifier).upsertContact(
                      type,
                      valueCtrl.text.trim(),
                    );
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
