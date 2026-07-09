import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/card_printing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/price_reference_hint.dart';
import '../post_wanted_provider.dart';
import '../post_wanted_repository.dart';

class PostWantedScreen extends ConsumerStatefulWidget {
  /// Texto con el que arranca el buscador de cartas (viene de `?q=` en la
  /// ruta, p. ej. desde un empty state de "no encontré la carta").
  final String? initialQuery;

  const PostWantedScreen({super.key, this.initialQuery});

  @override
  ConsumerState<PostWantedScreen> createState() => _PostWantedScreenState();
}

class _PostWantedScreenState extends ConsumerState<PostWantedScreen> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // El provider de query no es autoDispose: sincronizarlo siempre evita que
    // quede texto residual de una visita anterior. Microtask porque no se
    // puede mutar un provider durante el build del árbol.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(wantedCardSearchQueryProvider.notifier).state =
          widget.initialQuery ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publicar búsqueda',
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
                        initialQuery: widget.initialQuery,
                        onSelected: (_) => setState(() => _step = 1),
                      ),
                      _ConditionPriceStep(
                        onBack: () => setState(() => _step = 0),
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
    final form = ref.read(postWantedFormProvider);
    if (!form.isValid) return;

    try {
      await ref.read(postWantedRepositoryProvider).createWantedOrder(
            cardPrintingId: form.cardPrinting!.id,
            minCondition: form.minCondition,
            maxPrice: form.maxPrice,
            quantity: form.quantity,
            description: form.description,
            cityId: form.cityId,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    ref.read(postWantedFormProvider.notifier).reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Búsqueda publicada!')),
    );
    context.go('/wanted');
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Carta', 'Detalles'];

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

class _CardSearchStep extends ConsumerStatefulWidget {
  final String? initialQuery;
  final ValueChanged<CardPrinting> onSelected;
  const _CardSearchStep({this.initialQuery, required this.onSelected});

  @override
  ConsumerState<_CardSearchStep> createState() => _CardSearchStepState();
}

class _CardSearchStepState extends ConsumerState<_CardSearchStep> {
  late final _searchCtrl =
      TextEditingController(text: widget.initialQuery ?? '');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(wantedCardSearchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: 'Buscar carta (ej: Jinx)...',
            onChanged: (v) =>
                ref.read(wantedCardSearchQueryProvider.notifier).state = v,
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
                    message: 'Buscá la carta que estás buscando',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CardResultTile(
                      printing: items[i],
                      onTap: () {
                        ref
                            .read(postWantedFormProvider.notifier)
                            .setCardPrinting(items[i]);
                        widget.onSelected(items[i]);
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
                      ? CachedNetworkImage(
                          imageUrl: printing.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest),
                          errorWidget: (_, _, _) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.style_outlined,
                                size: 18, color: scheme.outline),
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
  final VoidCallback onSubmit;
  const _ConditionPriceStep({required this.onBack, required this.onSubmit});

  @override
  ConsumerState<_ConditionPriceStep> createState() =>
      _ConditionPriceStepState();
}

class _ConditionPriceStepState extends ConsumerState<_ConditionPriceStep> {
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  String? _condition;

  static const _conditionNames = {
    'NM': 'NM o mejor',
    'MP': 'MP o mejor',
    'HP': 'HP o mejor',
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
    final form = ref.watch(postWantedFormProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Condición mínima', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Cualquiera'),
                selected: _condition == null,
                onSelected: (_) {
                  setState(() => _condition = null);
                  ref.read(postWantedFormProvider.notifier).setMinCondition(null);
                },
              ),
              ..._conditionNames.entries.map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: _condition == e.key,
                    onSelected: (_) {
                      setState(() => _condition = e.key);
                      ref
                          .read(postWantedFormProvider.notifier)
                          .setMinCondition(e.key);
                    },
                  )),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
                labelText: 'Pago hasta (ARS)', prefixText: '\$ '),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v) ?? 0;
              ref.read(postWantedFormProvider.notifier).setMaxPrice(d);
            },
          ),
          if (form.cardPrinting != null)
            PriceReferenceHint(
              printingId: form.cardPrinting!.id,
              onSuggest: (ars) {
                _priceCtrl.text = ars.round().toString();
                ref.read(postWantedFormProvider.notifier).setMaxPrice(ars);
              },
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final q = int.tryParse(v) ?? 1;
              ref.read(postWantedFormProvider.notifier).setQuantity(q > 0 ? q : 1);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration:
                const InputDecoration(labelText: 'Descripción (opcional)'),
            maxLines: 3,
            onChanged: (v) => ref
                .read(postWantedFormProvider.notifier)
                .setDescription(v.isEmpty ? null : v),
          ),
          const SizedBox(height: 24),
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
