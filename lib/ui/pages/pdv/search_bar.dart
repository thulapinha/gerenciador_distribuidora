// lib/ui/pages/pdv/search_bar.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

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
  final Future<void> Function() onLookup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              decoration: const InputDecoration(
                hintText: 'Informe o código/sku/barras e pressione Enter ou use F2 para buscar',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onLookup,
            icon: const Icon(Icons.search),
            label: const Text('Buscar (F2)'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAddManual,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Produto (F3)'),
          ),
        ],
      ),
    );
  }
}

// ===================== Diálogo de busca ===========================
class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog({required this.repo, required this.initialText});

  final ProductRepository repo;
  final String initialText;

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  late final TextEditingController _termCtl;
  bool _loading = false;
  List<ParseObject> _results = [];

  @override
  void initState() {
    super.initState();
    _termCtl = TextEditingController(text: widget.initialText);
    _doSearch();
  }

  @override
  void dispose() {
    _termCtl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    setState(() => _loading = true);
    try {
      _results = await widget.repo.searchProducts(_termCtl.text.trim(), limit: 40);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar Produto (F2)'),
      content: SizedBox(
        width: 580,
        height: 440,
        child: Column(
          children: [
            TextField(
              controller: _termCtl,
              onSubmitted: (_) => _doSearch(),
              decoration: const InputDecoration(
                hintText: 'Digite nome/sku/código de barras',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('Sem resultados'))
                  : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _results[i];
                  final name = (p.get<String>('name') ?? '').toUpperCase();
                  final sku = p.get<String>('sku') ?? p.get<String>('barcode') ?? '';
                  final imageUrl = p.get<ParseFileBase>('image')?.url;

                  final priceUn = (p.get<num>('price') ?? 0).toDouble();
                  final packPrice = (p.get<num>('packPrice') ?? 0).toDouble();
                  final packQty = (p.get<num>('packQty') ?? 0).toDouble();

                  final hasCx = packQty > 0 && packPrice > 0;

                  Widget thumb() => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl == null
                        ? Container(
                      width: 40,
                      height: 40,
                      color: Colors.black12,
                      child: const Icon(Icons.inventory_2, size: 22),
                    )
                        : Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                  );

                  // Linha UN
                  final unTile = ListTile(
                    leading: thumb(),
                    title: Text('$name un'),
                    subtitle: Text('SKU: $sku'),
                    trailing: Text(_money(priceUn)),
                    onTap: () => Navigator.of(context).pop(_PdvItem(
                      productId: p.objectId,
                      name: '$name un',
                      qty: 1,
                      unitPrice: priceUn,
                      imageUrl: imageUrl,
                      uom: 'UN',
                      multiplier: 1,
                    )),
                  );

                  // Linha CX (se existir)
                  final cxTile = hasCx
                      ? ListTile(
                    leading: thumb(),
                    title: Text('$name cx'),
                    subtitle: Text('CX com ${packQty.toStringAsFixed(packQty.truncateToDouble()==packQty?0:2)} un • SKU: $sku'),
                    trailing: Text(_money(packPrice)),
                    onTap: () => Navigator.of(context).pop(_PdvItem(
                      productId: p.objectId,
                      name: '$name cx',
                      qty: 1,
                      unitPrice: packPrice,
                      imageUrl: imageUrl,
                      uom: 'CX',
                      multiplier: packQty,
                    )),
                  )
                      : null;

                  return Column(children: [unTile, if (cxTile != null) cxTile]);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        FilledButton(onPressed: _doSearch, child: const Text('Buscar')),
      ],
    );
  }
}

// Função auxiliar para abrir o diálogo a partir da página
Future<_PdvItem?> showProductSearchDialog({
  required BuildContext context,
  required ProductRepository repo,
  String initialText = '',
}) {
  return showDialog<_PdvItem>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _ProductSearchDialog(repo: repo, initialText: initialText),
  );
}
