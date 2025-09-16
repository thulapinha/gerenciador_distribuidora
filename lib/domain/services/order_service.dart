// lib/domain/services/order_service.dart
import 'dart:math';
import 'package:drift/drift.dart';
import '../../data/app_database.dart';
import 'inventory_service.dart';
import 'package:drift/drift.dart' as d;


class OrderService {
  final AppDatabase db;
  final InventoryService inventory;
  OrderService(this.db, this.inventory);

  Future<int> createDraftOrder({required int customerId}) async {
    final id = await db.into(db.orders).insert(OrdersCompanion.insert(
      customerId: customerId,
      status: Value(OrderStatus.draft),
    ));
    return id;
  }

  Future<int> addItem({required int orderId, required int productId, required double qty}) async {
    // preço simples pela tabela de preços
    final priceRow = await (db.select(db.prices)..where((p) => p.productId.equals(productId))).getSingleOrNull();
    final price = priceRow?.value ?? 0.0;
    final itemId = await db.into(db.orderItems).insert(OrderItemsCompanion.insert(
      orderId: orderId, productId: productId, qty: qty, price: Value(price), discount: const Value(0), bonusQty: const Value(0),
    ));

    // total do pedido (recalcular simples)
    final items = await (db.select(db.orderItems)..where((t) => t.orderId.equals(orderId))).get();
    final total = items.fold<double>(0.0, (sum, e) => sum + max(0, e.qty) * max(0, e.price - e.discount));
    await (db.update(db.orders)..where((o) => o.id.equals(orderId))).write(OrdersCompanion(total: Value(total)));

    return itemId;
  }

  /// Reserva estoque por FEFO para todos os itens do pedido.
  Future<void> reserveAll(int orderId) async {
    await db.transaction(() async {
      final items = await (db.select(db.orderItems)..where((t) => t.orderId.equals(orderId))).get();
      for (final it in items) {
        await inventory.reserveFefo(orderItemId: it.id, productId: it.productId, qtyNeeded: it.qty);
      }
      await (db.update(db.orders)..where((o) => o.id.equals(orderId))).write(
        OrdersCompanion(status: Value(OrderStatus.reserved)),
      );
    });
  }
}