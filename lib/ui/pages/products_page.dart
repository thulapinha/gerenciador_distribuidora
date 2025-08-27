import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_database.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppDatabase>().seedIfEmpty();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return FutureBuilder(
      future: db.select(db.products).get(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(title: const Text('Produtos')),
          body: ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = data[i];
              return ListTile(
                title: Text(p.description),
                subtitle: Text('SKU ${p.sku} | NCM ${p.ncm} | UN ${p.unit}'),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              // Exemplo rápido de inclusão
              await db.into(db.products).insert(
                ProductsCompanion.insert(sku: 'NOVO${DateTime.now().millisecondsSinceEpoch % 1000}', description: 'Produto Novo'),
              );
              if (context.mounted) setState(() {});
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}