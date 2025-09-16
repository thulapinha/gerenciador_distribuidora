import 'dart:convert';
import 'local_store.dart';

class SaleLine {
  final String? productId;
  final String name;
  final double qty;
  final double unitPrice;

  const SaleLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
  };
}

class SaleOfflineRepository {
  SaleOfflineRepository._();
  static final SaleOfflineRepository instance = SaleOfflineRepository._();

  /// Salva a venda localmente (fila) e aplica a baixa de estoque local.
  /// Retorna o ID local (S<timestamp>).
  Future<String> saveOffline({
    required List<SaleLine> items,
    required double discount,
    required String paymentMethod,
    required double received,
    required double total,
  }) async {
    final store = LocalStore.instance;
    final payload = <String, dynamic>{
      'total': total,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'received': received,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    final id = await store.queueSale(payload);

    // baixa local imediata (para refletir no PDV/estoque)
    await store.db.transaction((txn) async {
      for (final it in items) {
        if (it.productId != null && it.productId!.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE products SET stock = IFNULL(stock,0) - ? WHERE id = ?',
            [it.qty, it.productId],
          );
        }
      }
    });

    return id;
  }
}
