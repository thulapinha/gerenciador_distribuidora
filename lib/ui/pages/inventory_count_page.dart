import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import 'package:drift/drift.dart' as d;


class InventoryCountPage extends StatelessWidget {
  const InventoryCountPage({super.key});
  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Inventário Cíclico')),
      body: FutureBuilder(
        future: db.select(db.products).get(),
        builder: (_, snap) {
          final prods = snap.data ?? [];
          return ListView.separated(
            itemCount: prods.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = prods[i];
              return ListTile(
                title: Text(p.description),
                subtitle: Text('SKU ${p.sku}'),
                onTap: () async {
                  // Contagem simplificada: soma por produto e ajusta em um clique
                  final rows = await (db.select(db.stock)..where((s) => s.productId.equals(p.id))).get();
                  final current = rows.fold<double>(0.0, (s, e) => s + e.qty);
                  final newQty = current + 10; // exemplo: contagem encontrou +10
                  for (final s in rows) {
                    final share = s.qty / current;
                    final add = current == 0 ? 0 : (newQty - current) * share;
                    await (db.update(db.stock)..where((t) => t.id.equals(s.id))).write(
                        StockCompanion(qty: d.Value(s.qty + add))

                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ajuste aplicado para ${p.description}.')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}