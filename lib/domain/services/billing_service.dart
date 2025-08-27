// lib/domain/services/billing_service.dart
import 'package:drift/drift.dart';
import '../../data/app_database.dart';
import 'inventory_service.dart';
import 'package:drift/drift.dart' as d;


class BillingService {
  final AppDatabase db;
  final InventoryService inventory;
  BillingService(this.db, this.inventory);

  /// Gera "NF" simulada e títulos; confirma baixa do estoque.
  Future<void> simulateBilling(int orderId) async {
    await db.transaction(() async {
      // baixa estoque a partir das reservas
      await inventory.consumeReservationsForOrder(orderId);

      // títulos simples (1 parcela no prazo do cliente)
      final order = await (db.select(db.orders)..where((t) => t.id.equals(orderId))).getSingle();
      final cli = await (db.select(db.customers)..where((c) => c.id.equals(order.customerId))).getSingle();
      final due = DateTime.now().add(Duration(days: cli.paymentTermDays));

      await db.into(db.financialTitles).insert(FinancialTitlesCompanion.insert(
        customerId: order.customerId,
        originType: 'order',
        originId: orderId,
        dueDate: due,
        value: order.total,
      ));

      await (db.update(db.orders)..where((o) => o.id.equals(orderId))).write(
        OrdersCompanion(status: Value(OrderStatus.billed)),

      );

      await db.into(db.auditLogs).insert(AuditLogsCompanion.insert(
          action: 'billing_simulated', entity: 'order', entityId: orderId, beforeJson: const Value(null), afterJson: const Value(null)));
    });
  }
}