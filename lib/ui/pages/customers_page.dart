import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';
import 'package:drift/drift.dart' as d;


class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return FutureBuilder(
      future: db.select(db.customers).get(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),
          body: ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = data[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text('CNPJ/CPF ${c.cnpjCpf} | Rota ${c.route} | Prazo ${c.paymentTermDays}d'),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await db.into(db.customers).insert(CustomersCompanion.insert(
                cnpjCpf: '000.000.000-00', name: 'Novo Cliente',
                ie: const d.Value('ISENTO'),
                route: const d.Value('R2'),

              ));
              if (context.mounted) setState(() {});
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}