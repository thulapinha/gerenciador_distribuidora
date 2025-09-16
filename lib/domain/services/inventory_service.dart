// lib/domain/services/inventory_service.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/app_database.dart';

class InventoryService {
  final AppDatabase db;
  InventoryService(this.db);

  /// Aloca quantidade por FEFO (primeiro que vence) gerando reservas por lote.
  /// Retorna o mapa {lotId: qtyReservada}.
  Future<Map<int, double>> reserveFefo({
    required int orderItemId,
    required int productId,
    required double qtyNeeded,
    String actor = 'vendedor',
  }) async {
    return await db.transaction(() async {
      final rows = await (db.select(db.stock).join([
        innerJoin(db.lots, db.lots.id.equalsExp(db.stock.lotId)),
      ])
        ..where(db.stock.productId.equals(productId))
        ..where((db.stock.qty - db.stock.reservedQty)
            .isBiggerThan(const Constant(0.0)))
        ..orderBy([
          OrderingTerm(expression: db.lots.expiry, mode: OrderingMode.asc),
          OrderingTerm(expression: db.lots.code, mode: OrderingMode.asc),
        ]))
          .get();

      final alloc = <int, double>{};
      double remaining = qtyNeeded;

      for (final row in rows) {
        if (remaining <= 0) break;
        final s = row.readTable(db.stock);

        final available = ((s.qty - s.reservedQty)
            .clamp(0.0, double.infinity)) as double;
        if (available <= 0) continue;

        final take = available >= remaining ? remaining : available;

        // grava reserva
        await db.into(db.reservations).insert(ReservationsCompanion.insert(
          orderItemId: orderItemId,
          lotId: s.lotId,
          qty: take,
        ));
        // incrementa reservado
        await (db.update(db.stock)..where((tbl) => tbl.id.equals(s.id))).write(
          StockCompanion(reservedQty: Value(s.reservedQty + take)),
        );

        alloc[s.lotId] = (alloc[s.lotId] ?? 0) + take;
        remaining -= take;
      }

      if (remaining > 0.0001) {
        throw StateError(
            'Estoque insuficiente para o produto $productId: faltam $remaining');
      }

      await db.into(db.auditLogs).insert(AuditLogsCompanion.insert(
        action: 'reserve_fefo',
        entity: 'order_item',
        entityId: orderItemId,
        beforeJson: const Value(null),
        afterJson: Value(jsonEncode({'alloc': alloc})),
      ));

      return alloc;
    });
  }

  /// Baixa estoque confirmando as reservas (faturamento/saída).
  Future<void> consumeReservationsForOrder(int orderId,
      {String actor = 'faturista'}) async {
    await db.transaction(() async {
      final items = await (db.select(db.orderItems)
        ..where((t) => t.orderId.equals(orderId)))
          .get();
      for (final it in items) {
        final res = await (db.select(db.reservations)
          ..where((r) => r.orderItemId.equals(it.id)))
            .get();
        for (final r in res) {
          final s = await (db.select(db.stock)
            ..where((s) => s.lotId.equals(r.lotId)))
              .getSingle();
          final newQty = s.qty - r.qty;
          final newRes =
          ((s.reservedQty - r.qty).clamp(0.0, double.infinity)) as double;
          await (db.update(db.stock)..where((tbl) => tbl.id.equals(s.id)))
              .write(
            StockCompanion(
              qty: Value(newQty),
              reservedQty: Value(newRes),
            ),
          );
        }
      }
      await db.into(db.auditLogs).insert(AuditLogsCompanion.insert(
          action: 'consume_reservations',
          entity: 'order',
          entityId: orderId,
          beforeJson: const Value(null),
          afterJson: const Value(null)));
    });
  }
}
