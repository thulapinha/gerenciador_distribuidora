// lib/domain/services/auth_service.dart
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class AuthService {
  Future<ParseUser?> currentUser() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    return user;
  }

  Future<ParseUser> login(String username, String password) async {
    final user = ParseUser(username, password, null);
    final resp = await user.login();
    if (!resp.success) {
      throw Exception(resp.error?.message ?? 'Falha no login');
    }
    return resp.result as ParseUser;
  }

  Future<void> logout() async {
    final user = await currentUser();
    if (user != null) {
      await user.logout();
    }
  }

  Future<bool> isAdmin() async {
    final user = await currentUser();
    final role = user?.get<String>('role') ?? 'cashier';
    return role.toLowerCase() == 'admin';
  }
}
