// lib/pages/products/products_list_page.dart
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../../repositories/product_repository.dart';
import 'product_form_page.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  final _repo = ProductRepository();
  final _searchCtl = TextEditingController();
  bool _loading = true;
  List<ParseObject> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_searchCtl.text.trim().isEmpty) {
        _items = await _repo.listAll(limit: 100);
      } else {
        _items = await _repo.searchProducts(_searchCtl.text.trim(), limit: 100);
      }
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _newProduct() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductFormPage()),
    );
    if (ok == true) _load();
  }

  Future<void> _editProduct(ParseObject obj) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(productId: obj.objectId)),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(onPressed: _newProduct, icon: const Icon(Icons.add), tooltip: 'Novo produto'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome/SKU/código de barras',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _load, child: const Text('Buscar')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado'))
                : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = _items[i];
                final name = o.get<String>('name') ?? '-';
                final sku = o.get<String>('sku') ?? '-';
                final unit = o.get<String>('unit') ?? 'UN';
                final stock = (o.get<num>('stock') ?? 0).toDouble();
                final price = (o.get<num>('price') ?? 0).toDouble();

                return ListTile(
                  title: Text(name),
                  subtitle: Text('SKU: $sku • Estoque: $stock $unit • Preço: R\$ ${price.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editProduct(o),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
