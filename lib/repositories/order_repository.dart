import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class OrderRepository {
  static const _className = 'Order';
  static const _itemClass = 'OrderItem';

  Future<ParseObject> create({
    String? customerId,
    String? number,
    String? notes,
  }) async {
    final o = ParseObject(_className);
    if (customerId != null) {
      o.set<ParseObject>('customer', ParseObject('Customer')..objectId = customerId);
    }
    if (number != null) o.set<String>('number', number);
    if (notes != null) o.set<String>('notes', notes);
    o.set<String>('status', 'OPEN');
    final r = await o.save();
    if (!r.success) throw Exception(r.error?.message);
    return r.result as ParseObject;
  }

  Future<ParseObject> addItem({
    required String orderId,
    required String productId,
    required double qty,
    double? unitPrice,
  }) async {
    final order = ParseObject(_className)..objectId = orderId;
    final product = ParseObject('Product')..objectId = productId;

    // Se unitPrice não for passado, tenta puxar do produto
    double price = unitPrice ?? 0;
    if (unitPrice == null) {
      final p = await ParseObject('Product').getObject(productId);
      if (p.success && p.result != null) {
        price = ((p.result as ParseObject).get<num>('price') ?? 0).toDouble();
      }
    }

    final it = ParseObject(_itemClass)
      ..set<ParseObject>('order', order)
      ..set<ParseObject>('product', product)
      ..set<num>('qty', qty)
      ..set<num>('unitPrice', price)
      ..set<num>('total', price * qty);

    final r = await it.save();
    if (!r.success) throw Exception(r.error?.message);
    return r.result as ParseObject;
  }

  Future<void> removeItem(String orderItemId) async {
    final it = ParseObject(_itemClass)..objectId = orderItemId;
    final r = await it.delete();
    if (!r.success) throw Exception(r.error?.message);
  }

  Future<void> setStatus(String orderId, String status) async {
    final o = ParseObject(_className)..objectId = orderId;
    o.set<String>('status', status);
    final r = await o.save();
    if (!r.success) throw Exception(r.error?.message);
  }

  Future<List<ParseObject>> list({int limit = 100}) async {
    final q = QueryBuilder(ParseObject(_className))
      ..orderByDescending('createdAt')
      ..setLimit(limit);
    final r = await q.query();
    if (!r.success) throw Exception(r.error?.message);
    return (r.results ?? []).cast<ParseObject>();
  }

  Future<List<ParseObject>> itemsOf(String orderId) async {
    final q = QueryBuilder(ParseObject(_itemClass))
      ..whereEqualTo('order', ParseObject(_className)..objectId = orderId)
      ..includeObject(['product'])
      ..setLimit(500)
      ..orderByAscending('createdAt');
    final r = await q.query();
    if (!r.success) throw Exception(r.error?.message);
    return (r.results ?? []).cast<ParseObject>();
  }

  Future<void> deleteOrder(String orderId) async {
    // apaga itens
    final items = await itemsOf(orderId);
    for (final it in items) {
      await it.delete();
    }
    // apaga pedido
    final o = ParseObject(_className)..objectId = orderId;
    final r = await o.delete();
    if (!r.success) throw Exception(r.error?.message);
  }
}
