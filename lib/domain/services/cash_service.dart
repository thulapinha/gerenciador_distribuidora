import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class CashService {
  Future<Map<String, dynamic>> open(double openingAmount) async {
    final fn = ParseCloudFunction('openCashSession');
    final r = await fn.execute(parameters: {'openingAmount': openingAmount});
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao abrir');
    return Map<String, dynamic>.from(r.result as Map);
  }

  Future<void> suprimento(double amount, {String? note}) async {
    final fn = ParseCloudFunction('addCashMovement');
    final r = await fn.execute(parameters: {'type': 'SUPRIMENTO', 'amount': amount, 'note': note});
    if (!r.success) throw Exception(r.error?.message ?? 'Falha no suprimento');
  }

  Future<void> sangria(double amount, {String? note}) async {
    final fn = ParseCloudFunction('addCashMovement');
    final r = await fn.execute(parameters: {'type': 'SANGRIA', 'amount': amount, 'note': note});
    if (!r.success) throw Exception(r.error?.message ?? 'Falha na sangria');
  }

  Future<Map<String, dynamic>> close(double declared) async {
    final fn = ParseCloudFunction('closeCashSession');
    final r = await fn.execute(parameters: {'declaredClosingAmount': declared});
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao fechar');
    return Map<String, dynamic>.from(r.result as Map);
  }

  Future<Map<String, dynamic>> status() async {
    final fn = ParseCloudFunction('getCashSessionStatus');
    final r = await fn.execute();
    if (!r.success) throw Exception(r.error?.message ?? 'Falha no status');
    return Map<String, dynamic>.from(r.result as Map);
  }

  Future<Map<String, dynamic>> report({String? sessionId}) async {
    final fn = ParseCloudFunction('getCashSessionReport');
    final r = await fn.execute(parameters: sessionId == null ? null : {'sessionId': sessionId});
    if (!r.success) throw Exception(r.error?.message ?? 'Falha no relatório');
    return Map<String, dynamic>.from(r.result as Map);
  }

  Future<String> role() async {
    final fn = ParseCloudFunction('getAccessProfile');
    final r = await fn.execute();
    if (!r.success) throw Exception(r.error?.message ?? 'Falha ao obter perfil');
    final m = Map<String, dynamic>.from(r.result as Map);
    return (m['role'] as String? ?? '').toLowerCase();
  }
}
