import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import 'package:drift/drift.dart' as d;


class StockPage extends StatelessWidget {
  const StockPage({super.key});
  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final q = db.select(db.stock).join([
      d.innerJoin(db.products, db.products.id.equalsExp(db.stock.productId)),
      d.innerJoin(db.lots, db.lots.id.equalsExp(db.stock.lotId)),
      d.innerJoin(db.warehouses, db.warehouses.id.equalsExp(db.stock.warehouseId)),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Estoque (por Lote)')),
      body: FutureBuilder(
        future: q.get(),
        builder: (_, snap) {
          final rows = snap.data ?? [];
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = rows[i].readTable(db.stock);
              final p = rows[i].readTable(db.products);
              final l = rows[i].readTable(db.lots);
              final w = rows[i].readTable(db.warehouses);
              return ListTile(
                title: Text('${p.description} — Lote ${l.code}'),
                subtitle: Text('Depósito ${w.name} • End. ${s.address} • Validade ${l.expiry.toLocal()}'),
                trailing: Text('QTD: ${s.qty.toStringAsFixed(0)}  (Res: ${s.reservedQty.toStringAsFixed(0)})'),
              );
            },
          );
        },
      ),
    );
  }
}