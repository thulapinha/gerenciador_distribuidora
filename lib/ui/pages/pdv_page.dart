import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../domain/services/sales_service.dart';

class PdvPage extends StatefulWidget {
  const PdvPage({super.key});

  @override
  State<PdvPage> createState() => _PdvPageState();
}

class _PdvPageState extends State<PdvPage> {
  final TextEditingController searchCtrl = TextEditingController();
  final List<_CartItem> cart = [];

  Future<void> _addProduct(String query) async {
    final db = context.read<AppDatabase>();
    final prod = await (db.select(db.products)
          ..where((p) => p.code.equals(query) | p.description.like('%' + query + '%')))
        .getSingleOrNull();
    if (prod == null) return;
    final priceRow = await (db.select(db.prices)
          ..where((p) => p.productId.equals(prod.id)))
        .getSingleOrNull();
    final price = priceRow?.value ?? 0.0;
    setState(() {
      cart.add(_CartItem(prod.id, prod.description, 1, price));
    });
  }

  double get total =>
      cart.fold<double>(0.0, (sum, e) => sum + e.price * e.qty);

  Future<void> _finalize() async {
    final svc = context.read<SalesService>();
    await svc.registerSale(
      customerId: 1,
      items: [
        for (final c in cart)
          SaleItem(productId: c.productId, qty: c.qty, price: c.price)
      ],
    );
    if (!mounted) return;
    setState(() => cart.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Venda finalizada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar produto',
              ),
              onSubmitted: (v) {
                _addProduct(v.trim());
                searchCtrl.clear();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: cart.length,
                itemBuilder: (_, i) {
                  final it = cart[i];
                  return ListTile(
                    title: Text(it.description),
                    subtitle: Text('Qtd: ' + it.qty.toString() +
                        ' • R\$ ' + (it.price * it.qty).toStringAsFixed(2)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => cart.removeAt(i)),
                    ),
                  );
                },
              ),
            ),
            Text('Total: R\$ ' + total.toStringAsFixed(2)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: cart.isEmpty ? null : _finalize,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItem {
  final int productId;
  final String description;
  double qty;
  double price;
  _CartItem(this.productId, this.description, this.qty, this.price);
}

