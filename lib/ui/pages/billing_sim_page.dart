import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import '../../../domain/services/billing_service.dart';
import 'package:drift/drift.dart' as d;


class BillingSimPage extends StatelessWidget {
  const BillingSimPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final billing = context.read<BillingService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Faturamento Simulado')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final reserved = await (db.select(db.orders)..where((o) => o.status.equals(OrderStatus.reserved.index))).get();
                  if (reserved.isEmpty) return;
                  await billing.simulateBilling(reserved.first.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pedido #${reserved.first.id} faturado (simulado).')),
                    );
                  }
                },
                icon: const Icon(Icons.receipt),
                label: const Text('Faturar (simulado) primeiro reservado'),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: db.select(db.financialTitles).get(),
              builder: (_, snap) {
                final titles = snap.data ?? [];
                return ListView.separated(
                  itemCount: titles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = titles[i];
                    final st = t.status;

                    return ListTile(
                      title: Text('Título #${t.id} — R\$ ${t.value.toStringAsFixed(2)}'),
                      subtitle: Text('Venc ${t.dueDate.toLocal()} • ${t.originType} ${t.originId} • ${st.name}'),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}