import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import '../../../core/csv_export.dart';
import 'package:drift/drift.dart' as d;


class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          ElevatedButton(
            onPressed: () async {
              final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
              final rows = <List<dynamic>>[];
              final q = db.select(db.stock).join([
                d.innerJoin(db.products, db.products.id.equalsExp(db.stock.productId)),
                d.innerJoin(db.lots, db.lots.id.equalsExp(db.stock.lotId)),
              ]);
              final data = await q.get();
              rows.add(['Produto', 'SKU', 'Lote', 'Validade', 'QTD', 'Reservada']);
              for (final r in data) {
                final s = r.readTable(db.stock);
                final p = r.readTable(db.products);
                final l = r.readTable(db.lots);
                rows.add([p.description, p.sku, l.code, l.expiry.toIso8601String(), s.qty, s.reservedQty]);
              }
              final file = await saveCsv('estoque.csv', rows, Directory(dir.path));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: ${file.path}')));
              }
            },
            child: const Text('Exportar Estoque'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
              final data = await db.select(db.orders).get();
              final rows = <List<dynamic>>[['Pedido', 'Cliente', 'Status', 'Total', 'Criado em']];
              for (final o in data) {
                rows.add([o.id, o.customerId, o.status, o.total, o.createdAt.toIso8601String()]);
              }
              final file = await saveCsv('pedidos.csv', rows, Directory(dir.path));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: ${file.path}')));
              }
            },
            child: const Text('Exportar Pedidos'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
              final data = await db.select(db.financialTitles).get();
              final rows = <List<dynamic>>[['Título', 'Cliente', 'Origem', 'ID Origem', 'Vencimento', 'Valor', 'Status']];
              for (final t in data) {
                rows.add([t.id, t.customerId, t.originType, t.originId, t.dueDate.toIso8601String(), t.value, t.status]);
              }
              final file = await saveCsv('titulos.csv', rows, Directory(dir.path));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: ${file.path}')));
              }
            },
            child: const Text('Exportar Títulos'),
          ),
        ]),
      ),
    );
  }
}