import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductRepository();
  final _searchCtl = TextEditingController();
  bool _loading = true;
  List<ParseObject> _all = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      debugPrint('[ProductsPage] load...');
      final q = QueryBuilder(ParseObject('Product'))
        ..orderByAscending('name')
        ..setLimit(300);
      final r = await q.query();
      debugPrint('[ProductsPage] load resp success=${r.success} count=${(r.results ?? []).length} err=${r.error?.message}');
      if (!r.success) throw Exception(r.error?.message);
      if (!mounted) return;
      setState(() { _all = (r.results ?? []).cast<ParseObject>(); _loading = false; });
    } catch (e) {
      debugPrint('[ProductsPage] load ERROR: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Erro ao carregar: $e');
    }
  }

  Future<void> _confirmAndDelete(ParseObject p) async {
    final name = p.get<String>('name') ?? '-';
    debugPrint('[ProductsPage] delete confirm for $name (${p.objectId})');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('Deseja excluir "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;

    final closeProgress = _showProgressBlocking(context, 'Excluindo produto...');
    try {
      final id = p.objectId!;
      debugPrint('[ProductsPage] calling repo.delete($id)');
      final deleted = await _repo.delete(id);
      debugPrint('[ProductsPage] repo.delete -> deleted=$deleted');
      if (!mounted) return;
      setState(() { _all.removeWhere((e) => e.objectId == id); });
      _snack(deleted ? 'Produto excluído.' : 'Produto inativado (active=false).');
    } catch (e) {
      debugPrint('[ProductsPage] delete ERROR: $e');
      if (mounted) _snack('Erro ao excluir: $e');
    } finally {
      closeProgress();
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final term = _searchCtl.text.trim().toLowerCase();
    final list = term.isEmpty
        ? _all
        : _all.where((o) {
      final name = (o.get<String>('name') ?? '').toLowerCase();
      final sku  = (o.get<String>('sku')  ?? '').toLowerCase();
      final bc   = (o.get<String>('barcode') ?? '').toLowerCase();
      final brand= (o.get<String>('brand') ?? '').toLowerCase();
      return name.contains(term) || sku.contains(term) || bc.contains(term) || brand.contains(term);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push<bool>('/produtos/novo');
          if (ok == true && mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nome/SKU/código/brand',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? const Center(child: Text('Sem produtos'))
                  : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = list[i];
                  final name = o.get<String>('name') ?? '-';
                  final sku  = o.get<String>('sku')  ?? '-';
                  final ncm  = o.get<String>('ncm')  ?? '—';
                  final unit = o.get<String>('unit') ?? 'UN';
                  final brand= o.get<String>('brand');
                  final active = o.get<bool>('active') ?? true;

                  return ListTile(
                    title: Row(
                      children: [
                        if (!active) const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.block, size: 18, color: Colors.redAccent),
                        ),
                        Expanded(child: Text(name)),
                      ],
                    ),
                    subtitle: Text([
                      'SKU $sku', 'NCM $ncm', unit, if (brand != null && brand.isNotEmpty) brand
                    ].join(' | ')),
                    onTap: () async {
                      final ok = await context.push<bool>('/produtos/editar/${o.objectId}');
                      if (ok == true && mounted) _load();
                    },
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            final ok = await context.push<bool>('/produtos/editar/${o.objectId}');
                            if (ok == true && mounted) _load();
                          },
                        ),
                        IconButton(
                          tooltip: 'Excluir',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmAndDelete(o),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

VoidCallback _showProgressBlocking(BuildContext context, String message) {
  debugPrint('[ProductsPage/UI] show progress "$message"');
  bool closed = false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(40),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 14),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final timer = Timer(const Duration(seconds: 12), () {
    if (!closed) {
      debugPrint('[ProductsPage/UI] progress failsafe close');
      Navigator.of(context, rootNavigator: true).maybePop();
      closed = true;
    }
  });

  return () {
    if (!closed) {
      debugPrint('[ProductsPage/UI] progress close');
      Navigator.of(context, rootNavigator: true).maybePop();
      closed = true;
    }
    timer.cancel();
  };
}
