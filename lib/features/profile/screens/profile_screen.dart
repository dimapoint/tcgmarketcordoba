import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/models/profile.dart';
import '../profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final contactsAsync = ref.watch(contactMethodsProvider);
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.isAdmin ?? false;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (profile) => profile == null
                  ? const SizedBox()
                  : _ProfileBody(
                      profile: profile,
                      contactsAsync: contactsAsync,
                      isAdmin: isAdmin,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final Profile profile;
  final AsyncValue<List<ContactMethod>> contactsAsync;
  final bool isAdmin;
  const _ProfileBody({
    required this.profile,
    required this.contactsAsync,
    required this.isAdmin,
  });

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

  static (IconData, String) _contactStyle(String type) => switch (type) {
        'whatsapp' => (Icons.chat, 'WhatsApp'),
        'instagram' => (Icons.camera_alt, 'Instagram'),
        'telegram' => (Icons.send, 'Telegram'),
        'email' => (Icons.email, 'Email'),
        _ => (Icons.contact_page, type),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mi perfil',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Salir'),
              onPressed: () =>
                  ref.read(authActionsProvider.notifier).signOut(),
            ),
          ],
        ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Panel de administración'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
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
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.save_outlined),
                      tooltip: 'Guardar',
                      onPressed: () => ref
                          .read(profileActionsProvider.notifier)
                          .updateUsername(_usernameCtrl.text.trim()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Métodos de contacto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Así te van a contactar los compradores.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                widget.contactsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Text('Error: $e'),
                  data: (contacts) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...contacts.map((c) {
                        final (icon, label) = _contactStyle(c.type);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                scheme.primary.withValues(alpha: 0.12),
                            child: Icon(icon, size: 20, color: scheme.primary),
                          ),
                          title: Text(label),
                          subtitle: Text(c.value),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: scheme.error),
                            tooltip: 'Eliminar',
                            onPressed: () => ref
                                .read(profileActionsProvider.notifier)
                                .deleteContact(c.id),
                          ),
                        );
                      }),
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
            ),
          ),
        ),
      ],
    );
  }

  void _showAddContactDialog(BuildContext context) {
    String type = 'whatsapp';
    final valueCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? submitError;

    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar contacto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
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
                  onChanged: (v) => setDialogState(() {
                    type = v!;
                    submitError = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    hintText: 'Número, usuario, etc.',
                  ),
                  validator: (v) => _validateContactValue(type, v),
                ),
                if (submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    submitError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref.read(profileActionsProvider.notifier).upsertContact(
                      type,
                      valueCtrl.text.trim(),
                    );
                final state = ref.read(profileActionsProvider);
                if (state.hasError) {
                  setDialogState(() => submitError = state.error.toString());
                  return;
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Validación rápida en el cliente, en espejo de las reglas del backend
/// (`backend/internal/profiles/contact_validation.go`) para dar feedback
/// inmediato — el backend sigue siendo la fuente de verdad.
String? _validateContactValue(String type, String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Campo requerido';
  switch (type) {
    case 'whatsapp':
      final digits = v.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
      return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(digits)
          ? null
          : 'Número de WhatsApp inválido';
    case 'instagram':
      final handle = v.replaceFirst(RegExp(r'^@'), '');
      return RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(handle)
          ? null
          : 'Usuario de Instagram inválido';
    case 'telegram':
      final handle = v.replaceFirst(RegExp(r'^@'), '');
      return RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(handle)
          ? null
          : 'Usuario de Telegram inválido';
    case 'email':
      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
          ? null
          : 'Email inválido';
    default:
      return null;
  }
}
