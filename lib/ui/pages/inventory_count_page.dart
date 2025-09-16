// lib/ui/pages/inventory_count_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class InventoryCountPage extends StatefulWidget {
  const InventoryCountPage({super.key});

  @override
  State<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends State<InventoryCountPage> {
  final _repo = ProductRepository();

  final TextEditingController _codeCtl = TextEditingController();
  final TextEditingController _searchCtl = TextEditingController();

  // mapa por productId para rápido acesso
  final Map<String, _InvItem> _items = {};
  String? _selectedId;

  bool _applying = false;

  // ===================================================================
  // Helpers
  // ===================================================================
  String _money(num v) => 'R\$ ' + v.toStringAsFixed(2).replaceAll('.', ',');
  String _fmtQty(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  double get _totalDiff =>
      _items.values.fold(0.0, (p, e) => p + (e.counted - e.current));

  int get _lines => _items.length;

  // Busca robusta por qualquer código (SKU, código de barras ou nome)
  Future<ParseObject?> _findByAnyCode(String term) async {
    final bySku = await _repo.getBySku(term, includeInactive: true);
    if (bySku != null) return bySku;

    final byBar = await _repo.getByBarcode(term, includeInactive: true);
    if (byBar != null) return byBar;

    final list = await _repo.searchProducts(term, limit: 10, includeInactive: true);
    if (list.length == 1) return list.first;

    return null;
  }

  // ===================================================================
  // Fluxo principal
  // ===================================================================
  Future<void> _addByCodeOrSearch() async {
    final term = _codeCtl.text.trim();
    if (term.isEmpty) {
      await _openLookupDialog();
      return;
    }

    final close = _showBlockingOverlay(context, 'Buscando produto...');
    try {
      final p = await _findByAnyCode(term).timeout(const Duration(seconds: 10));
      if (p == null) {
        close();
        await _openLookupDialog(prefill: term);
        return;
      }
      _addOrIncFromParse(p);
      _codeCtl.clear();
    } on TimeoutException {
      _snack('Tempo esgotado na busca. Tente novamente.');
    } catch (e) {
      _snack('Erro na busca: $e');
    } finally {
      close();
    }
  }

  void _addOrIncFromParse(ParseObject p) {
    final id = p.objectId!;
    final name = p.get<String>('name') ?? 'Produto';
    final sku = p.get<String>('sku') ?? '-';
    final unit = p.get<String>('unit') ?? 'UN';
    final current = (p.get<num>('stock') ?? 0).toDouble();

    setState(() {
      final existing = _items[id];
      if (existing != null) {
        existing.counted += 1;
        _selectedId = id;
      } else {
        _items[id] = _InvItem(
          productId: id,
          name: name,
          sku: sku,
          unit: unit,
          current: current,
          counted: 1,
        );
        _selectedId = id;
      }
    });
  }

  Future<void> _openLookupDialog({String? prefill}) async {
    final termCtl = TextEditingController(text: prefill ?? '');
    List<ParseObject> results = [];
    bool loading = false;

    Future<void> doSearch(StateSetter setD) async {
      setD(() => loading = true);
      results = await _repo.searchProducts(termCtl.text.trim(), limit: 40, includeInactive: true);
      setD(() => loading = false);
    }

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDState) => AlertDialog(
          title: const Text('Buscar Produto'),
          content: SizedBox(
            width: 620,
            height: 440,
            child: Column(
              children: [
                TextField(
                  controller: termCtl,
                  onSubmitted: (_) => doSearch(setDState),
                  decoration: const InputDecoration(
                    hintText: 'Digite nome/SKU/código de barras',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : results.isEmpty
                      ? const Center(child: Text('Sem resultados'))
                      : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = results[i];
                      final name = p.get<String>('name') ?? '';
                      final price = (p.get<num>('price') ?? 0).toDouble();
                      final sku = p.get<String>('sku') ?? p.get<String>('barcode') ?? '';
                      final stock = (p.get<num>('stock') ?? 0).toDouble();

                      return ListTile(
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('SKU: $sku • Estoque: ${_fmtQty(stock)}'),
                        trailing: Text(_money(price)),
                        onTap: () {
                          Navigator.of(dctx).pop();
                          _addOrIncFromParse(p);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Fechar')),
            FilledButton(onPressed: () => doSearch(setDState), child: const Text('Buscar')),
          ],
        ),
      ),
    );
  }

  Future<void> _editCount(String id) async {
    final it = _items[id]!;
    final ctl = TextEditingController(text: _fmtQty(it.counted));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: Text('Contagem para ${it.name}'),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantidade contada'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok == true) {
      final v = _parseDecimal(ctl.text);
      if (v >= 0) setState(() => _items[id] = it.copyWith(counted: v));
    }
  }

  // Parser robusto BR/US
  double _parseDecimal(String input) {
    var s = input.trim();
    if (s.isEmpty) return 0.0;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0.0;
  }

  // ===================================================================
  // Aplicação dos ajustes
  // ===================================================================
  Future<void> _applySetToCounted() async {
    if (_items.isEmpty) {
      _snack('Nenhum item contado.');
      return;
    }
    final toApply = _items.values.where((e) => (e.counted - e.current).abs() > 0.0001).toList();
    if (toApply.isEmpty) {
      _snack('Todas as quantidades já coincidem com o contado.');
      return;
    }

    final ok = await _confirm('Definir estoque EXATAMENTE para o valor contado de ${toApply.length} item(s)?');
    if (ok != true) return;

    final close = _showBlockingOverlay(context, 'Aplicando ajustes (setStock)...');
    setState(() => _applying = true);
    int success = 0, fail = 0;
    try {
      for (final it in toApply) {
        try {
          await _repo.setStock(it.productId, it.counted);
          success++;
        } catch (_) {
          fail++;
        }
      }
      _snack('Ajustes aplicados: $success sucesso(s), $fail falha(s).');
      setState(() {
        for (final it in _items.values) {
          _items[it.productId] = it.copyWith(current: it.counted);
        }
      });
    } finally {
      close();
      setState(() => _applying = false);
    }
  }

  Future<void> _applyDeltaAdjust() async {
    if (_items.isEmpty) {
      _snack('Nenhum item contado.');
      return;
    }
    final toApply = _items.values.where((e) => (e.counted - e.current).abs() > 0.0001).toList();
    if (toApply.isEmpty) {
      _snack('Todas as quantidades já coincidem com o contado.');
      return;
    }

    final ok = await _confirm('Gerar ajustes (Δ) para ${toApply.length} item(s)?');
    if (ok != true) return;

    final close = _showBlockingOverlay(context, 'Aplicando ajustes (delta)...');
    setState(() => _applying = true);
    int success = 0, fail = 0;
    try {
      for (final it in toApply) {
        final delta = it.counted - it.current;
        try {
          await _repo.adjustStock(it.productId, delta);
          success++;
        } catch (_) {
          fail++;
        }
      }
      _snack('Ajustes aplicados: $success sucesso(s), $fail falha(s).');
      setState(() {
        for (final it in _items.values) {
          _items[it.productId] = it.copyWith(current: it.counted);
        }
      });
    } finally {
      close();
      setState(() => _applying = false);
    }
  }

  Future<bool?> _confirm(String msg) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dctx) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
  }

  // ===================================================================
  // UI
  // ===================================================================
  @override
  void dispose() {
    _codeCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          const Text('Inventário • Conferência de Estoque',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtl,
                  onSubmitted: (_) => _addByCodeOrSearch(),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.qr_code_scanner),
                    hintText: 'Informe o código/SKU/barras e pressione Enter, ou clique em Buscar…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _openLookupDialog,
                icon: const Icon(Icons.search),
                label: const Text('Buscar (F2)'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _items.isEmpty
                    ? null
                    : () => setState(() {
                  _items.clear();
                  _selectedId = null;
                }),
                icon: const Icon(Icons.clear_all),
                label: const Text('Zerar Sessão'),
              ),
            ],
          ),
        ],
      ),
    );

    final totalsBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _kpiCard(
            title: 'Itens na sessão',
            value: '$_lines',
            icon: Icons.list_alt_outlined,
          ),
          _kpiCard(
            title: 'Diferença total (Δ)',
            value: _fmtQty(_totalDiff),
            icon: Icons.swap_vert,
          ),
        ],
      ),
    );

    final tableHeader = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          _HCell(width: 112, child: Text('Código')),
          _HCell(flex: 3, child: Text('Produto')),
          _HCell(width: 120, child: Text('Estoque Atual')),
          _HCell(width: 156, child: Text('Contado')),  // << mais folga
          _HCell(width: 120, child: Text('Diferença')),
          _HCell(width: 96, child: SizedBox()),
        ],
      ),
    );

    final list = _filteredList();

    final tableBody = Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              tableHeader,
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Nenhum item contado ainda'))
                    : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (_, i) {
                    final it = list[i];
                    final selected = it.productId == _selectedId;
                    final diff = it.counted - it.current;
                    final diffColor = diff.abs() < 0.0001
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : (diff > 0 ? Colors.green.shade700 : Colors.red.shade700);

                    return InkWell(
                      onTap: () => setState(() => _selectedId = it.productId),
                      child: Container(
                        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const _HCell(width: 112, child: SizedBox()),
                            // o código aparece como texto:
                            _HCell(width: 112, child: Text(it.sku)),
                            _HCell(flex: 3, child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            _HCell(width: 120, child: Text('${_fmtQty(it.current)} ${it.unit}')),
                            _HCell(
                              width: 156, // << bate com o header
                              child: Row(
                                children: [
                                  _MiniIconButton(
                                    tooltip: 'Diminuir',
                                    onPressed: () => setState(() {
                                      final v = (it.counted - 1);
                                      _items[it.productId] = it.copyWith(counted: v < 0 ? 0 : v);
                                    }),
                                    icon: Icons.remove,
                                  ),
                                  GestureDetector(
                                    onTap: () => _editCount(it.productId),
                                    child: Container(
                                      width: 54,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(_fmtQty(it.counted)),
                                    ),
                                  ),
                                  _MiniIconButton(
                                    tooltip: 'Aumentar',
                                    onPressed: () => setState(() {
                                      _items[it.productId] = it.copyWith(counted: it.counted + 1);
                                    }),
                                    icon: Icons.add,
                                  ),
                                ],
                              ),
                            ),
                            _HCell(
                              width: 120,
                              child: Text(
                                _fmtQty(diff),
                                style: TextStyle(fontWeight: FontWeight.w700, color: diffColor),
                              ),
                            ),
                            _HCell(
                              width: 96,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _MiniIconButton(
                                    tooltip: 'Editar contagem',
                                    onPressed: () => _editCount(it.productId),
                                    icon: Icons.edit_outlined,
                                  ),
                                  _MiniIconButton(
                                    tooltip: 'Remover da sessão',
                                    onPressed: () => setState(() => _items.remove(it.productId)),
                                    icon: Icons.delete_outline,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _pagerAndSearchBar(),
            ],
          ),
        ),
      ),
    );

    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _applying ? null : _applySetToCounted,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Ajustar para Contado (setStock)'),
                ),
                FilledButton.icon(
                  onPressed: _applying ? null : _applyDeltaAdjust,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Gerar Ajustes (Δ)'),
                ),
              ],
            ),
          ),
          if (_applying) const SizedBox(width: 10),
          if (_applying) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          totalsBar,
          tableBody,
          actions,
        ],
      ),
    );
  }

  // Filtro rápido por nome/SKU
  List<_InvItem> _filteredList() {
    final term = _searchCtl.text.trim().toLowerCase();
    final all = _items.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (term.isEmpty) return all;
    return all
        .where((e) => e.name.toLowerCase().contains(term) || e.sku.toLowerCase().contains(term))
        .toList();
  }

  Widget _pagerAndSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Filtrar por nome ou código (local na sessão)',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({required String title, required String value, required IconData icon}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// ===========================================================================
// Models / Widgets auxiliares
// ===========================================================================
class _InvItem {
  final String productId;
  final String sku;
  final String name;
  final String unit;
  final double current;
  late final double counted;

  _InvItem({
    required this.productId,
    required this.sku,
    required this.name,
    required this.unit,
    required this.current,
    required this.counted,
  });

  _InvItem copyWith({
    double? current,
    double? counted,
  }) {
    return _InvItem(
      productId: productId,
      sku: sku,
      name: name,
      unit: unit,
      current: current ?? this.current,
      counted: counted ?? this.counted,
    );
  }
}

class _HCell extends StatelessWidget {
  const _HCell({this.flex, this.width, required this.child});
  final int? flex;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = Align(alignment: Alignment.centerLeft, child: child);
    if (width != null) {
      return SizedBox(width: width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: w));
    }
    return Expanded(flex: flex ?? 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: w));
  }
}

/// Botão compacto para não estourar a largura
class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      splashRadius: 18,
      tooltip: tooltip,
    );
    return btn;
  }
}

// Overlay progress “à prova de travar”
VoidCallback _showBlockingOverlay(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  var removed = false;

  entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
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

  final timer = Timer(const Duration(seconds: 20), () {
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
