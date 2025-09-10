// lib/ui/pages/stock_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _repo = ProductRepository();
  final _searchCtl = TextEditingController();

  bool _loading = true;
  List<ParseObject> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ====================================================================
  // DATA
  // ====================================================================
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      debugPrint('[StockPage] load...');
      final q = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..orderByAscending('name')
        ..setLimit(600);
      final r = await q.query();
      debugPrint('[StockPage] resp success=${r.success} count=${(r.results ?? []).length} err=${r.error?.message}');
      if (!r.success) throw Exception(r.error?.message);

      if (!mounted) return;
      setState(() {
        _all = (r.results ?? []).cast<ParseObject>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[StockPage] load ERROR: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Erro ao carregar: $e');
    }
  }

  Future<void> _confirmAndDelete(ParseObject p) async {
    final name = p.get<String>('name') ?? '-';
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text('Tem certeza que deseja excluir "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Progress por Overlay (não usa Navigator) + timeout/failsafe
    final closeProgress = _showBlockingOverlay(context, 'Excluindo produto...');
    try {
      final id = p.objectId!;
      // evita pendurar indefinidamente
      final deleted = await _repo.delete(id).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _all.removeWhere((e) => e.objectId == id);
      });
      _snack(deleted ? 'Produto excluído.' : 'Produto inativado (active=false).');
    } on TimeoutException {
      if (mounted) _snack('Tempo esgotado ao excluir. Verifique a conexão e tente novamente.');
    } catch (e) {
      if (mounted) _snack('Erro ao excluir: $e');
    } finally {
      closeProgress(); // fecha SEMPRE
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ====================================================================
  // UI
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = _searchCtl.text.trim().toLowerCase();
    final list = term.isEmpty
        ? _all
        : _all.where((o) {
      final name = (o.get<String>('name') ?? '').toLowerCase();
      final sku = (o.get<String>('sku') ?? '').toLowerCase();
      final bc = (o.get<String>('barcode') ?? '').toLowerCase();
      return name.contains(term) || sku.contains(term) || bc.contains(term);
    }).toList();

    // HEADER (gradiente + busca)
    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estoque (por Produto)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtl,
                  onSubmitted: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nome/SKU/código de barras',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loading ? null : () => setState(() {}),
                icon: const Icon(Icons.tune),
                label: const Text('Filtrar'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
              ),
            ],
          ),
        ],
      ),
    );

    // LISTA dentro de um "card" com cantos arredondados
    final listCard = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: _load,
            child: list.isEmpty
                ? _EmptyState(onReload: _load)
                : Column(
              children: [
                // barra superior do card
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    '${list.length} item${list.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                    itemBuilder: (_, i) {
                      final o = list[i];
                      final name = o.get<String>('name') ?? '-';
                      final sku = o.get<String>('sku') ?? '-';
                      final unit = o.get<String>('unit') ?? 'UN';
                      final stock = (o.get<num>('stock') ?? 0).toDouble();
                      final min = (o.get<num>('minStock') ?? 0).toDouble();
                      final active = o.get<bool>('active') ?? true;

                      // cores do chip
                      final bool low = stock <= min;
                      final Color chipBg = low
                          ? Colors.red.withOpacity(.12)
                          : Colors.green.withOpacity(.12);
                      final Color chipFg = low
                          ? Colors.red.shade700
                          : Colors.green.shade700;

                      // leve destaque para baixo estoque/inativo
                      final rowBg = !active
                          ? cs.errorContainer.withOpacity(.08)
                          : (low ? cs.errorContainer.withOpacity(.06) : null);

                      return InkWell(
                        onTap: () {}, // reservado
                        child: Container(
                          color: rowBg,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 64,
                          child: Row(
                            children: [
                              // nome + status "inativo"
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (!active)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: Icon(Icons.block, size: 18, color: Colors.redAccent),
                                          ),
                                        Flexible(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('SKU: $sku • Unidade: $unit',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12.5,
                                        )),
                                  ],
                                ),
                              ),
                              // Quantidade (chip) + excluir
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: chipBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'QTD ${_fmtQty(stock)} ($unit)',
                                      style: TextStyle(
                                        color: chipFg,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir',
                                    onPressed: () => _confirmAndDelete(o),
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          listCard,
        ],
      ),
    );
  }

  String _fmtQty(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
}

// ====================== Widgets auxiliares ==================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('Sem produtos no estoque',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Cadastre produtos ou ajuste os filtros para vê-los aqui.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Overlay progress "à prova de travar"
VoidCallback _showBlockingOverlay(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  var removed = false;

  entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Colors.black54,
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(message)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);

  // Failsafe (15s)
  final timer = Timer(const Duration(seconds: 15), () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
  });

  return () {
    if (!removed) {
      entry.remove();
      removed = true;
    }
    timer.cancel();
  };
}
