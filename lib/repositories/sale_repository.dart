// lib/repositories/sales_repository.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Repositório de Vendas (Parse)
///
/// Classe "Sale"
/// Campos esperados:
/// - total (Number)          : total líquido da venda (após desconto)
/// - discount (Number)       : desconto absoluto
/// - paymentMethod (String)  : 'CASH', 'PIX', 'CARD_CREDIT', etc.
/// - received (Number)       : recebido (para cálculo de troco)
/// - items (List<Map>)       : [{qty, unitPrice, ...}] (opcional)
/// - createdAt (Date)        : data/hora da venda
class SalesRepository {
  static const String className = 'Sale';

  Future<List<ParseObject>> listSales({
    required DateTime start,
    required DateTime end,
    List<String>? paymentMethods,
    int limit = 1000,
    int skip = 0,
  }) async {
    debugPrint('[SalesRepo] listSales $start -> $end methods=$paymentMethods');
    final q = QueryBuilder<ParseObject>(ParseObject(className))
      ..whereGreaterThanOrEqualsTo('createdAt', start.toUtc())
      ..whereLessThan('createdAt', end.toUtc())
      ..orderByDescending('createdAt')
      ..setLimit(limit)
      ..setAmountToSkip(skip);

    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      q.whereContainedIn('paymentMethod', paymentMethods);
    }

    final r = await q.query();
    if (!r.success) {
      throw Exception('Erro ao listar vendas: ${r.error?.message}');
    }
    return (r.results ?? []).cast<ParseObject>();
  }

  FinanceTotals computeTotals(Iterable<ParseObject> sales) {
    double gross = 0, discount = 0, net = 0, received = 0, change = 0;
    final byMethod = <String, double>{};
    var count = 0;

    for (final s in sales) {
      final d = (s.get<num>('discount') ?? 0).toDouble();
      final t = _netFromSale(s);
      final rcv = (s.get<num>('received') ?? t).toDouble();
      final chg = math.max(0, rcv - t);
      final pm = (s.get<String>('paymentMethod') ?? 'UNKNOWN').toUpperCase();

      discount += d;
      net += t;
      gross += t + d;
      received += rcv;
      change += chg;
      count += 1;

      byMethod.update(pm, (v) => v + t, ifAbsent: () => t);
    }

    return FinanceTotals(
      gross: gross,
      discount: discount,
      net: net,
      received: received,
      change: change,
      count: count,
      byMethod: byMethod..removeWhere((k, v) => v == 0),
    );
  }

  double _netFromSale(ParseObject sale) {
    final total = sale.get<num>('total');
    if (total != null) return total.toDouble();

    // Fallback pelo somatório dos itens menos desconto
    final items = sale.get<List>('items') ?? const [];
    double sum = 0;
    for (final it in items) {
      if (it is Map) {
        final q = (it['qty'] as num?)?.toDouble() ?? 0;
        final p = (it['unitPrice'] as num?)?.toDouble() ?? 0;
        sum += q * p;
      }
    }
    final disc = (sale.get<num>('discount') ?? 0).toDouble();
    return math.max(0, sum - disc);
  }
}

class FinanceTotals {
  FinanceTotals({
    required this.gross,
    required this.discount,
    required this.net,
    required this.received,
    required this.change,
    required this.count,
    required this.byMethod,
  });

  final double gross;
  final double discount;
  final double net;
  final double received;
  final double change;
  final int count;
  final Map<String, double> byMethod;
}
