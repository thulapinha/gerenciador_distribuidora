import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class UserManagementService {
  Future<void> createUser({required String username, required String password, String role = 'cashier', String? name}) async {
    final fn = ParseCloudFunction('createUser');
    final resp = await fn.execute(parameters: {'username': username, 'password': password, 'role': role, 'name': name});
    if (!resp.success) throw Exception(resp.error?.message ?? 'Falha ao criar usuário');
  }

  Future<void> resetPassword({required String userId, required String newPassword}) async {
    final fn = ParseCloudFunction('resetUserPassword');
    final resp = await fn.execute(parameters: {'userId': userId, 'password': newPassword});
    if (!resp.success) throw Exception(resp.error?.message ?? 'Falha ao resetar senha');
  }

  Future<void> setRole({required String userId, required String role}) async {
    final fn = ParseCloudFunction('setUserRole');
    final resp = await fn.execute(parameters: {'userId': userId, 'role': role});
    if (!resp.success) throw Exception(resp.error?.message ?? 'Falha ao alterar papel');
  }
}
