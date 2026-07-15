import 'package:flutter/material.dart';

class AdminFilterBar extends StatefulWidget {
  final String status;
  final List<(String, String)> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  const AdminFilterBar({
    super.key,
    required this.status,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });

  @override
  State<AdminFilterBar> createState() => _AdminFilterBarState();
}

class _AdminFilterBarState extends State<AdminFilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: widget.statusOptions
                .map((o) => ChoiceChip(
                      label: Text(o.$2),
                      selected: widget.status == o.$1,
                      onSelected: (_) => widget.onStatusChanged(o.$1),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  widget.onQueryChanged('');
                },
              ),
              hintText: 'Buscar por carta o usuario',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: widget.onQueryChanged,
          ),
        ],
      ),
    );
  }
}
