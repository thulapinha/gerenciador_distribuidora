import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class SaleRepository {
  Future<Map<String, dynamic>> finalizeSale({
    required List<Map<String, dynamic>> items,
    double discount = 0,
    String paymentMethod = 'CASH',
    double received = 0,
    String? number,
  }) async {
    final func = ParseCloudFunction('finalizeSale');
    final params = {
      'items': items,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'received': received,
      'number': number,
    };
    final resp = await func.execute(parameters: params);
    if (!resp.success) {
      throw Exception('Erro ao finalizar venda: ${resp.error?.message}');
    }
    return Map<String, dynamic>.from(resp.result);
  }
}
