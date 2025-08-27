// lib/core/di.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../domain/services/inventory_service.dart';
import '../domain/services/order_service.dart';
import '../domain/services/billing_service.dart';
import '../domain/services/sales_service.dart';

class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, db) => db.close(),
      child: Builder(builder: (context) {
        final db = context.read<AppDatabase>();
        return MultiProvider(
          providers: [
            Provider(create: (_) => InventoryService(db)),
            Provider(create: (ctx) => OrderService(db, ctx.read<InventoryService>())),
            Provider(create: (ctx) => BillingService(db, ctx.read<InventoryService>())),
            Provider(create: (ctx) =>
                SalesService(db, ctx.read<InventoryService>(), ctx.read<BillingService>())),
          ],
          child: child,
        );
      }),
    );
  }
}