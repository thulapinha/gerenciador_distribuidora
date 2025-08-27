import 'package:drift/drift.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../data/app_database.dart';
import 'inventory_service.dart';
import 'billing_service.dart';

/// Representa um item de venda no PDV.
class SaleItem {
  final int productId;
  final double qty;
  final double price;

  const SaleItem({required this.productId, required this.qty, required this.price});
}

/// Serviço responsável por registrar vendas e acionar estoque e financeiro.
class SalesService {
  final AppDatabase db;
  final InventoryService inventory;
  final BillingService billing;

  SalesService(this.db, this.inventory, this.billing);

  /// Registra a venda, baixa estoque via [InventoryService] e gera títulos via
  /// [BillingService]. Também envia a venda para o Parse Server.
  Future<int> registerSale({
    required int customerId,
    required List<SaleItem> items,
  }) async {
    return await db.transaction(() async {
      // cria pedido base para reaproveitar infraestrutura existente
      final orderId = await db.into(db.orders).insert(OrdersCompanion.insert(
            customerId: customerId,
            status: const Value(OrderStatus.draft),
          ));

      // adiciona itens e reserva estoque
      for (final it in items) {
        final priceRow = await (db.select(db.prices)
              ..where((p) => p.productId.equals(it.productId)))
            .getSingleOrNull();
        final price = priceRow?.value ?? it.price;
        final itemId = await db.into(db.orderItems).insert(
              OrderItemsCompanion.insert(
                orderId: orderId,
                productId: it.productId,
                qty: it.qty,
                price: Value(price),
                discount: const Value(0),
                bonusQty: const Value(0),
              ),
            );

        await inventory.reserveFefo(
          orderItemId: itemId,
          productId: it.productId,
          qtyNeeded: it.qty,
        );
      }

      // recalcula total do pedido
      final itemsRows = await (db.select(db.orderItems)
            ..where((t) => t.orderId.equals(orderId)))
          .get();
      final total = itemsRows
          .fold<double>(0.0, (sum, e) => sum + e.qty * e.price);
      await (db.update(db.orders)
            ..where((o) => o.id.equals(orderId)))
          .write(OrdersCompanion(total: Value(total)));

      // baixa estoque e gera títulos financeiros
      await billing.simulateBilling(orderId);

      // envia para Parse
      final saleObj = ParseObject('Sale')
        ..set('orderId', orderId)
        ..set('customerId', customerId)
        ..set('total', total)
        ..set('items', [
          for (final e in itemsRows)
            {
              'productId': e.productId,
              'qty': e.qty,
              'price': e.price,
            }
        ]);
      await saleObj.save();

      return orderId;
    });
  }
}

