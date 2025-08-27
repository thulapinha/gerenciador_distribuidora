import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import '../../../domain/services/order_service.dart';
import 'package:drift/drift.dart' as d;


class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int? selectedCustomer;
  int? selectedProduct;
  double qty = 1;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final orderSvc = context.read<OrderService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pré-venda (Pedido → Reserva FEFO)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: db.select(db.customers).get(),
              builder: (_, snap) {
                final items = snap.data ?? [];
                return DropdownButton<int>(
                  value: selectedCustomer,
                  hint: const Text('Selecione o cliente'),
                  items: [for (final c in items) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => selectedCustomer = v),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: db.select(db.products).get(),
              builder: (_, snap) {
                final items = snap.data ?? [];
                return DropdownButton<int>(
                  value: selectedProduct,
                  hint: const Text('Selecione o produto'),
                  items: [for (final p in items) DropdownMenuItem(value: p.id, child: Text(p.description))],
                  onChanged: (v) => setState(() => selectedProduct = v),
                );
              },
            ),
            Row(children: [
              const Text('Qtd:'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: qty, min: 1, max: 100, divisions: 99,
                  onChanged: (v) => setState(() => qty = v),
                ),
              ),
              SizedBox(width: 60, child: Text(qty.toStringAsFixed(0), textAlign: TextAlign.end)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(
                onPressed: selectedCustomer == null ? null : () async {
                  final orderId = await orderSvc.createDraftOrder(customerId: selectedCustomer!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido #$orderId criado.')));
                },
                icon: const Icon(Icons.add),
                label: const Text('Criar pedido'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  // pega último pedido rascunho
                  final last = await (db.select(db.orders)
                    ..where((o) => o.status.equals(OrderStatus.draft.index))
                    ..where((o) => o.status.equalsValue(OrderStatus.draft))
                    ..orderBy([(o) => d.OrderingTerm(
                      expression: o.createdAt,
                      mode: d.OrderingMode.desc,
                    )])

                    ..limit(1))
                      .getSingleOrNull();
                  if (last == null || selectedProduct == null) return;
                  await orderSvc.addItem(orderId: last.id, productId: selectedProduct!, qty: qty);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item adicionado.')));
                },
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Adicionar item'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final last = await (db.select(db.orders)
                    ..where((o) => o.status.equals(OrderStatus.draft.index))
                    ..where((o) => o.status.equalsValue(OrderStatus.draft))
                    ..orderBy([(o) => d.OrderingTerm(
                      expression: o.createdAt,
                      mode: d.OrderingMode.desc,
                    )])

                    ..limit(1))
                      .getSingleOrNull();
                  if (last == null) return;
                  await orderSvc.reserveAll(last.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedido #${last.id} reservado (FEFO).')));
                },
                icon: const Icon(Icons.inventory),
                label: const Text('Reservar (FEFO)'),
              ),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder(
                future: db.select(db.orders).get(),
                builder: (_, snap) {
                  final orders = snap.data ?? [];
                  return ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final o = orders[i];
                      final status = o.status;

                      return ListTile(
                        title: Text('Pedido #${o.id} • Total R\$ ${o.total.toStringAsFixed(2)}'),
                        subtitle: Text('Cliente ${o.customerId} • ${status.name} • ${o.createdAt.toLocal()}'),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}