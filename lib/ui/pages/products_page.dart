// lib/ui/pages/products_page.dart
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'package:gerenciador_distribuidora/repositories/product_repository.dart';
import 'package:gerenciador_distribuidora/ui/pages/products/product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductRepository();
  final _searchCtl = TextEditingController();

  bool _loading = true;
  int _rowsPerPage = 20;
  int _page = 0;
  int _totalCount = 0;

  List<ParseObject> _items = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 0;
    if (mounted) setState(() => _loading = true);

    try {
      final search = _searchCtl.text.trim();
      final offset = _page * _rowsPerPage;

      if (offset == 0) {
        if (search.isEmpty) {
          final list = await _repo.listAll(limit: _rowsPerPage, orderField: 'sku');
          if (!mounted) return;
          _items = list;
        } else {
          final list = await _repo.searchProducts(search, limit: _rowsPerPage);
          if (!mounted) return;
          _items = list;
        }
      } else {
        final page = await _listPageWithParse(search: search, skip: offset, limit: _rowsPerPage);
        if (!mounted) return;
        _items = page;
      }

      _totalCount = await _countTotal(search.isEmpty ? null : search);
      if (!mounted) return;
    } catch (e) {
      if (mounted) _snack('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<ParseObject>> _listPageWithParse({
    required String search,
    required int skip,
    required int limit,
  }) async {
    if (search.isEmpty) {
      final q = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..orderByAscending('sku')
        ..setAmountToSkip(skip)
        ..setLimit(limit);

      final res = await q.query();
      return (res.success && res.results != null) ? res.results!.cast<ParseObject>() : <ParseObject>[];
    } else {
      final nameQ = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..whereContains('name', search);
      final skuQ = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..whereContains('sku', search);
      final barQ = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..whereContains('barcode', search);

      final orQ = QueryBuilder.or(ParseObject('Product'), [nameQ, skuQ, barQ])
        ..orderByAscending('sku')
        ..setAmountToSkip(skip)
        ..setLimit(limit);

      final res = await orQ.query();
      return (res.success && res.results != null) ? res.results!.cast<ParseObject>() : <ParseObject>[];
    }
  }

  Future<int> _countTotal(String? search) async {
    try {
      if (search != null && search.isNotEmpty) {
        final q1 = QueryBuilder<ParseObject>(ParseObject('Product'))..whereContains('name', search);
        final q2 = QueryBuilder<ParseObject>(ParseObject('Product'))..whereContains('sku', search);
        final q3 = QueryBuilder<ParseObject>(ParseObject('Product'))..whereContains('barcode', search);
        final orQ = QueryBuilder.or(ParseObject('Product'), [q1, q2, q3]);
        final res = await orQ.count();
        if (res.success) return res.count ?? 0;
        return 0;
      } else {
        final q = QueryBuilder<ParseObject>(ParseObject('Product'));
        final res = await q.count();
        if (res.success) return res.count ?? 0;
        return 0;
      }
    } catch (_) {
      return _items.length;
    }
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductFormPage(), fullscreenDialog: true),
    );
    if (ok == true) _load();
  }

  Future<void> _openEdit(ParseObject o) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(productId: o.objectId), fullscreenDialog: true),
    );
    if (ok == true) _load();
  }

  void _nextPage() {
    if ((_page + 1) * _rowsPerPage >= _totalCount) return;
    setState(() => _page += 1);
    _load();
  }

  void _prevPage() {
    if (_page == 0) return;
    setState(() => _page -= 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
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
          const Text('SIGE Lite  ›  Produto', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Mais Ações',
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'import', child: Text('Importar/Exportar')),
                  PopupMenuItem(value: 'stock', child: Text('Controle de Estoque')),
                  PopupMenuItem(value: 'cashback', child: Text('Cashback por Produto')),
                ],
                onSelected: (_) {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text('Mais Ações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _openCreate, style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('Adicionar')),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtl,
                  onSubmitted: (_) => _load(reset: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Busca Rápida',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
                label: const Text('Filtrar', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: () {}, icon: const Icon(Icons.print, color: Colors.white)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.view_column_outlined, color: Colors.white)),
            ],
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
          _HCell(width: 96, child: Text('Código')),
          _HCell(width: 80, child: Text('Tipo')),
          _HCell(flex: 3, child: Text('Nome')),
          _HCell(width: 160, child: Text('Preço de Venda')),
          _HCell(width: 80, child: SizedBox()),
        ],
      ),
    );

    final tableBody = Expanded(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('Nenhum produto encontrado'))
          : ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
        itemBuilder: (_, i) {
          final p = _items[i];
          final code = p.get<String>('sku') ?? '';
          final name = p.get<String>('name') ?? '';
          final price = (p.get<num>('price') ?? 0).toDouble();

          return SizedBox(
            height: 52,
            child: InkWell(
              onTap: () => _openEdit(p),
              child: Row(
                children: [
                  _HCell(width: 96, child: Text(code)),
                  const _HCell(width: 80, child: Icon(Icons.inventory_2_outlined, size: 18)),
                  _HCell(flex: 3, child: Text(name)),
                  _HCell(width: 160, child: Text('R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}')),
                  _HCell(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [IconButton(onPressed: () => _openEdit(p), icon: const Icon(Icons.edit_outlined))],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final pager = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Spacer(),
          const Text('Itens por página'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50')),
              DropdownMenuItem(value: 100, child: Text('100')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _rowsPerPage = v);
              _load(reset: true);
            },
          ),
          const SizedBox(width: 12),
          Text(_rangeText()),
          IconButton(onPressed: _prevPage, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _nextPage, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
                child: Column(children: [tableHeader, tableBody, pager]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rangeText() {
    if (_totalCount == 0) return '0 de 0';
    final start = _page * _rowsPerPage + 1;
    final end = ((_page + 1) * _rowsPerPage).clamp(1, _totalCount);
    return '$start – $end de $_totalCount itens';
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
      return SizedBox(width: width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: w));
    }
    return Expanded(flex: flex ?? 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: w));
  }
}
