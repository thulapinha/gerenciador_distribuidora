// lib/ui/pages/pdv/search_bar.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Search ================================================================
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onAddManual,
    required this.onLookup,
  });
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onAddManual;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.qr_code_scanner),
                hintText: 'Informe o código/sku/barras e pressione Enter ou use F2 para buscar…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), tooltip: 'Buscar (F2)', onPressed: onLookup),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddManual,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('ADICIONAR PRODUTO (F3)'),
          )
        ],
      ),
    );
  }
}
