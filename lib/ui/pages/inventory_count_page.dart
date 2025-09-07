import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class InventoryCountPage extends StatefulWidget {
  const InventoryCountPage({super.key});

  @override
  State<InventoryCountPage> createState() => _InventoryCountPageState();
}

class _InventoryCountPageState extends State<InventoryCountPage> {
  bool _loading = true;
  final _searchCtl = TextEditingController();
  List<ParseObject> _all = [];
  List<ParseObject> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtl.addListener(_apply);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = QueryBuilder(ParseObject('Product'))
        ..orderByAscending('name')
        ..setLimit(1000);
      final r = await q.query();
      if (!r.success) throw Exception(r.error?.message);
      _all = (r.results ?? []).cast<ParseObject>();
      _filtered = _all;
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _apply() {
    final t = _searchCtl.text.toLowerCase().trim();
    setState(() {
      if (t.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((o) {
          final n = (o.get<String>('name') ?? '').toLowerCase();
          final sku = (o.get<String>('sku') ?? '').toLowerCase();
          return n.contains(t) || sku.contains(t);
        }).toList();
      }
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventário Cíclico')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nome/SKU',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = _filtered[i];
                  final name = o.get<String>('name') ?? '-';
                  final sku = o.get<String>('sku') ?? '-';
                  final unit = o.get<String>('unit') ?? 'UN';
                  final stock = (o.get<num>('stock') ?? 0).toDouble();
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('SKU $sku'),
                    trailing: Text('${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1)} $unit'),
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
