import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Camada de acesso ao Parse para Pedidos de Pré-venda.
/// Tabelas sugeridas:
/// - Order      { number:int, customer:Pointer<Customer>, status:String[draft|reserved|invoiced], total:num }
/// - OrderItem  { order:Pointer<Order>, product:Pointer<Product>, productName, unit, factor, qty, qtyBase, unitPrice, total }
///
/// Observação: o "factor" é quantos "UN" existem na unidade escolhida (ex.: CX com 12 → factor=12).
class OrderRepository {
  /// Cria (ou retorna) um pedido em rascunho para um cliente.
  Future<ParseObject> createDraft({
    required ParseObject customer,
  }) async {
    final order = ParseObject('Order')
      ..set<ParseObject>('customer', customer)
      ..set<String>('status', 'draft')
      ..set<num>('total', 0);

    // (Opcional) gere number sequencial por Cloud Code.
    // Se não tiver, tudo bem: salvar sem 'number'.
    final res = await order.save();
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Falha ao criar pedido');
    }
    return res.results!.first as ParseObject;
  }

  /// Lista pedidos (padrão 50), mais novos primeiro.
  Future<List<ParseObject>> list({int limit = 50}) async {
    final q = QueryBuilder<ParseObject>(ParseObject('Order'))
      ..orderByDescending('createdAt')
      ..setLimit(limit);
    final r = await q.query();
    if (!r.success) return <ParseObject>[];
    return (r.results ?? []).cast<ParseObject>();
  }

  /// Carrega itens de um pedido.
  Future<List<ParseObject>> listItems(String orderId) async {
    final orderPtr = (ParseObject('Order')..objectId = orderId).toPointer();
    final q = QueryBuilder<ParseObject>(ParseObject('OrderItem'))
      ..whereEqualTo('order', orderPtr)
      ..orderByAscending('createdAt')
      ..setLimit(500);
    final r = await q.query();
    if (!r.success) return <ParseObject>[];
    return (r.results ?? []).cast<ParseObject>();
  }

  /// Adiciona um item ao pedido.
  /// - [unit]  = 'UN' | 'CX' | 'KG' (ou outra sigla que você usar)
  /// - [factor]= 1 para UN; para CX, número de unidades por caixa; para KG, use 1 e trate valor como kg.
  /// - [qty]   = quantidade na unidade escolhida; [qtyBase] = quantidade convertida para UN.
  /// - [unitPriceBase] = preço por UN (o sistema calcula total = qtyBase * unitPriceBase)
  Future<ParseObject> addItem({
    required ParseObject order,
    required ParseObject product,
    required String productName,
    required String unit,
    required num factor,
    required num qty,
    required num qtyBase,
    required num unitPriceBase,
  }) async {
    final item = ParseObject('OrderItem')
      ..set<ParseObject>('order', order)
      ..set<ParseObject>('product', product)
      ..set<String>('productName', productName)
      ..set<String>('unit', unit)
      ..set<num>('factor', factor)
      ..set<num>('qty', qty)
      ..set<num>('qtyBase', qtyBase)
      ..set<num>('unitPrice', unitPriceBase)
      ..set<num>('total', qtyBase * unitPriceBase);

    final r = await item.save();
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao salvar item');
    return r.results!.first as ParseObject;
  }

  /// Remove um item e retorna o total recalculado do pedido.
  Future<num> removeItem(String itemId) async {
    final item = ParseObject('OrderItem')..objectId = itemId;
    final r = await item.delete();
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao remover item');

    // Recalcular total do pedido deste item (se quiser otimizar, faça por Cloud Code)
    final orderPtr = (r.results?.first as ParseObject?)?.get<ParseObject>('order');
    if (orderPtr == null) return 0;

    final q = QueryBuilder<ParseObject>(ParseObject('OrderItem'))
      ..whereEqualTo('order', orderPtr)
      ..setLimit(1000);
    final items = await q.query();
    final sum = (items.results ?? [])
        .cast<ParseObject>()
        .fold<num>(0, (p, e) => p + (e.get<num>('total') ?? 0));
    final upd = ParseObject('Order')
      ..objectId = orderPtr.objectId
      ..set<num>('total', sum);
    await upd.save();
    return sum;
  }

  /// Recalcula e grava o total do pedido.
  Future<num> updateOrderTotal(String orderId) async {
    final orderPtr = (ParseObject('Order')..objectId = orderId).toPointer();
    final q = QueryBuilder<ParseObject>(ParseObject('OrderItem'))
      ..whereEqualTo('order', orderPtr)
      ..setLimit(1000);
    final r = await q.query();
    final sum = (r.results ?? [])
        .cast<ParseObject>()
        .fold<num>(0, (p, e) => p + (e.get<num>('total') ?? 0));
    final upd = ParseObject('Order')
      ..objectId = orderId
      ..set<num>('total', sum);
    final u = await upd.save();
    if (!u.success) throw Exception(u.error?.message ?? 'Falha ao atualizar total');
    return sum;
  }

  /// Altera status. Para FEFO, marque "reserved".
  /// (Você pode integrar sua lógica de lotes aqui depois.)
  Future<void> setStatus(String orderId, String status,
      {Map<String, dynamic>? extra}) async {
    final o = ParseObject('Order')
      ..objectId = orderId
      ..set<String>('status', status);
    if (extra != null) {
      extra.forEach((k, v) => o.set<dynamic>(k, v));
    }
    final r = await o.save();
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao atualizar status');
  }

  /// Reserva FEFO (placeholder). Integre com Cloud Code quando disponível.
  Future<void> reserveFefo(String orderId) async {
    // Exemplo com Cloud Code:
    // final fn = ParseCloudFunction('reserveFefoForOrder');
    // final r = await fn.execute(parameters: {'orderId': orderId});
    // if (!r.success) throw Exception(r.error?.message ?? 'Falha no FEFO');
    await setStatus(orderId, 'reserved', extra: {'fefoApplied': true});
  }
}
