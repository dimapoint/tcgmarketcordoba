import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/price_reference_hint.dart';
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
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // El paso de búsqueda aprovecha pantallas anchas (más resultados
            // visibles); los pasos de formulario quedan en columna angosta.
            constraints: BoxConstraints(maxWidth: _step == 0 ? 900 : 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva publicación',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _StepIndicator(current: _step),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _step,
                    children: [
                      _CardSearchStep(
                          onSelected: (_) => setState(() => _step = 1)),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final result =
        await ref.read(postListingSubmitProvider.notifier).submit();
    if (!mounted) return;
    switch (result) {
      case SubmitSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Publicación creada!')),
        );
        context.go('/');
      case SubmitFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      case SubmitSkipped():
        break;
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Carta', 'Precio', 'Fotos'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= current ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? scheme.primary : scheme.surface,
                  border: i <= current
                      ? null
                      : Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: i < current
                      ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: i <= current
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _labels[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w400,
                      color: i <= current
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
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
                ref.read(cardSearchQueryProvider.notifier).set(v),
            leading: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => items.isEmpty
                ? const EmptyState(
                    icon: Icons.search,
                    message: 'Buscá la carta que querés vender',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CardResultTile(
                      printing: items[i],
                      onTap: () {
                        ref
                            .read(postListingFormProvider.notifier)
                            .setCardPrinting(items[i]);
                        onSelected(items[i]);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CardResultTile extends StatelessWidget {
  final CardPrinting printing;
  final VoidCallback onTap;
  const _CardResultTile({required this.printing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 56,
                  child: printing.thumbnailUrl != null
                      ? ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: CachedNetworkImage(
                            imageUrl: printing.thumbnailUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => ColoredBox(
                                color: scheme.surfaceContainerHighest),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.style_outlined,
                                  size: 18, color: scheme.outline),
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.style_outlined,
                              size: 18, color: scheme.outline),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
    Text(
                      printing.cardName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${printing.setName} · ${printing.setCode} #${printing.cardNumber}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (printing.wantedCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${printing.wantedCount} '
                        '${printing.wantedCount == 1 ? "persona busca" : "personas buscan"} esta carta',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (printing.isFoil)
                Text(
                  '✦ Foil',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.price(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
        ),
      ),
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
  final _quantityCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  String? _condition;

  // Opciones simples para el vendedor; se guardan como el enum
  // card_condition de la DB (que también admite LP y D en datos viejos).
  static const _conditionNames = {
    'NM': 'Nueva',
    'MP': 'Jugada',
    'HP': 'Muy usada',
  };

  @override
  void dispose() {
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(postListingFormProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Condición', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditionNames.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _condition == e.key,
                      onSelected: (_) {
                        setState(() => _condition = e.key);
                        ref
                            .read(postListingFormProvider.notifier)
                            .setCondition(e.key);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
                labelText: 'Precio (ARS)', prefixText: '\$ '),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v) ?? 0;
              ref.read(postListingFormProvider.notifier).setPrice(d);
            },
          ),
          if (form.cardPrinting != null)
            PriceReferenceHint(
              printingId: form.cardPrinting!.id,
              onSuggest: (ars) {
                // setState: el botón "Siguiente" lee _priceCtrl.text directo
                setState(() => _priceCtrl.text = ars.round().toString());
                ref.read(postListingFormProvider.notifier).setPrice(ars);
              },
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final q = int.tryParse(v) ?? 1;
              ref.read(postListingFormProvider.notifier).setQuantity(q > 0 ? q : 1);
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
                onPressed:
                    (_condition != null && _priceCtrl.text.isNotEmpty)
                        ? widget.onNext
                        : null,
                child: const Text('Siguiente'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PhotoStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  const _PhotoStep({required this.onBack, required this.onSubmit});

  // Se leen los bytes al elegir: en web el path del XFile es una blob URL
  // inutilizable con dart:io, los bytes funcionan en todas las plataformas.
  Future<void> _pickPhoto(WidgetRef ref) async {
    final photos = ref.read(postListingFormProvider).photos;
    if (photos.length >= 3) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    ref.read(postListingFormProvider.notifier).setPhotos([
      ...photos,
      PickedPhoto(bytes: bytes, filename: picked.name),
    ]);
  }

  void _removePhoto(WidgetRef ref, int i) {
    final photos = [...ref.read(postListingFormProvider).photos]..removeAt(i);
    ref.read(postListingFormProvider.notifier).setPhotos(photos);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(postListingFormProvider);
    final submitting = ref.watch(postListingSubmitProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Opcional, hasta 3. La primera es la portada.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...form.photos.asMap().entries.map((e) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Image.memory(e.value.bytes,
                                  width: 132, height: 132, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 14,
                          child: GestureDetector(
                            onTap: () => _removePhoto(ref, e.key),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: scheme.error,
                              child: Icon(Icons.close,
                                  size: 14, color: scheme.onError),
                            ),
                          ),
                        ),
                      ],
                    )),
                if (form.photos.length < 3)
                  InkWell(
                    onTap: () => _pickPhoto(ref),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                        color: scheme.surface,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(height: 6),
                          Text(
                            'Agregar foto',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Row(children: [
            OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (form.isValid && !submitting) ? onSubmit : null,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publicar'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
