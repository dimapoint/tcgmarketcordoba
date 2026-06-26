import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/supabase/client.dart';
import '../photo_repository.dart';
import '../post_listing_provider.dart';
import '../../../shared/models/card_printing.dart';

class PostListingScreen extends ConsumerStatefulWidget {
  const PostListingScreen({super.key});

  @override
  ConsumerState<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends ConsumerState<PostListingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: IndexedStack(
        index: _step,
        children: [
          _CardSearchStep(onSelected: (_) => setState(() => _step = 1)),
          _ConditionPriceStep(
            onBack: () => setState(() => _step = 0),
            onNext: () => setState(() => _step = 2),
          ),
          _PhotoStep(
            onBack: () => setState(() => _step = 1),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final form = ref.read(postListingFormProvider);
    if (!form.isValid) return;

    final sellerId = supabase.auth.currentUser!.id;

    final profile = await supabase
        .from('profiles')
        .select('city_id')
        .eq('id', sellerId)
        .single();
    final cityId = form.cityId ?? profile['city_id'] as String?;
    if (cityId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configurá tu ciudad en tu perfil primero.')),
      );
      return;
    }

    final listing = await supabase.from('listings').insert({
      'seller_id': sellerId,
      'card_printing_id': form.cardPrinting!.id,
      'condition': form.condition,
      'price': form.price,
      'description': form.description,
      'city_id': cityId,
    }).select().single();

    final listingId = listing['id'] as String;

    final photoRepo = ref.read(photoRepositoryProvider);
    for (var i = 0; i < form.photoPaths.length; i++) {
      final url = await photoRepo.upload(
        listingId: listingId,
        file: File(form.photoPaths[i]),
        order: i + 1,
      );
      await supabase.from('listing_photos').insert({
        'listing_id': listingId,
        'storage_path': url,
        'display_order': i + 1,
      });
    }

    ref.read(postListingFormProvider.notifier).reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Publicación creada!')),
    );
    context.go('/');
  }
}

class _CardSearchStep extends ConsumerWidget {
  final ValueChanged<CardPrinting> onSelected;
  const _CardSearchStep({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(cardSearchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            hintText: 'Buscar carta (ej: Jinx)...',
            onChanged: (v) =>
                ref.read(cardSearchQueryProvider.notifier).state = v,
            leading: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final cp = items[i];
                return ListTile(
                  title: Text(cp.displayName),
                  onTap: () {
                    ref
                        .read(postListingFormProvider.notifier)
                        .setCardPrinting(cp);
                    onSelected(cp);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConditionPriceStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _ConditionPriceStep({required this.onBack, required this.onNext});

  @override
  ConsumerState<_ConditionPriceStep> createState() =>
      _ConditionPriceStepState();
}

class _ConditionPriceStepState extends ConsumerState<_ConditionPriceStep> {
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _condition;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Condición',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['NM', 'LP', 'MP', 'HP', 'D']
                .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: _condition == c,
                      onSelected: (_) {
                        setState(() => _condition = c);
                        ref
                            .read(postListingFormProvider.notifier)
                            .setCondition(c);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
                labelText: 'Precio (ARS)', prefixText: '\$'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v) ?? 0;
              ref.read(postListingFormProvider.notifier).setPrice(d);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration:
                const InputDecoration(labelText: 'Descripción (opcional)'),
            maxLines: 3,
            onChanged: (v) => ref
                .read(postListingFormProvider.notifier)
                .setDescription(v.isEmpty ? null : v),
          ),
          const Spacer(),
          Row(children: [
            OutlinedButton(
                onPressed: widget.onBack, child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (_condition != null && _priceCtrl.text.isNotEmpty)
                    ? widget.onNext
                    : null,
                child: const Text('Siguiente'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PhotoStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  const _PhotoStep({required this.onBack, required this.onSubmit});

  @override
  ConsumerState<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends ConsumerState<_PhotoStep> {
  final List<File> _files = [];

  Future<void> _pickPhoto() async {
    if (_files.length >= 3) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _files.add(File(picked.path)));
    ref
        .read(postListingFormProvider.notifier)
        .setPhotoPaths(_files.map((f) => f.path).toList());
  }

  void _removePhoto(int i) {
    setState(() => _files.removeAt(i));
    ref
        .read(postListingFormProvider.notifier)
        .setPhotoPaths(_files.map((f) => f.path).toList());
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(postListingFormProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fotos (mínimo 1, máximo 3)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._files.asMap().entries.map((e) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.file(e.value,
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _removePhoto(e.key),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                if (_files.length < 3)
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Row(children: [
            OutlinedButton(
                onPressed: widget.onBack, child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: form.isValid ? widget.onSubmit : null,
                child: const Text('Publicar'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
