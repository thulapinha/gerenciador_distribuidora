// lib/domain/services/auth_service.dart
import 'dart:async';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../core/session.dart';
import '../../core/rbac.dart';

class AuthService {
  // Inicialize Parse antes (ex.: no main.dart)
  static Future<void> initParse({
    required String appId,
    required String serverUrl,
    String? clientKey,
    bool autoSendSessionId = true,
    bool debug = false,
  }) async {
    await Parse().initialize(
      appId,
      serverUrl,
      clientKey: clientKey,
      autoSendSessionId: autoSendSessionId,
      debug: debug,
    );

    // Se já existir user logado na SDK, sincroniza com Session
    final current = await ParseUser.currentUser() as ParseUser?;
    if (current != null && current.objectId != null) {
      Session.i.setUser(id: current.objectId, name: current.username);
      try {
        final p = await fetchAccessProfile();
        Session.i.setProfile(p);
      } catch (_) {
        // Ignora erro na inicialização
      }
    }
  }

  static Future<void> login(String username, String password) async {
    final user = ParseUser(username, password, null);
    final res = await user.login();
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Falha no login');
    }

    final u = res.result as ParseUser;
    Session.i.setUser(id: u.objectId, name: u.username);

    final profile = await fetchAccessProfile();
    Session.i.setProfile(profile);
  }

  static Future<void> logout() async {
    final current = await ParseUser.currentUser() as ParseUser?;
    if (current != null) {
      await current.logout();
    }
    await Session.i.clear();
  }

  static Future<AccessProfile> fetchAccessProfile() async {
    final fn = ParseCloudFunction('getAccessProfile');
    final res = await fn.execute();
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Erro ao obter perfil de acesso');
    }
    final data = (res.result as Map).map((k, v) => MapEntry(k.toString(), v));
    return AccessProfile.fromJson(data);
  }

  // ============== Admin de Usuários (Cloud Functions existentes) ==============

  static Future<List<UserRow>> listUsers() async {
    final fn = ParseCloudFunction('listUsers');
    final res = await fn.execute();
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Erro ao listar usuários');
    }
    final map = (res.result as Map).map((k, v) => MapEntry(k.toString(), v));
    final list = (map['users'] as List?) ?? const [];
    return list.map((e) => UserRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  static Future<String> createUser({
    required String username,
    required String password,
    String role = Roles.cashier,
    String? name,
  }) async {
    final fn = ParseCloudFunction('createUser');
    final res = await fn.execute(parameters: {
      'username': username,
      'password': password,
      'role': role,
      if (name != null) 'name': name,
    });
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Erro ao criar usuário');
    }
    final map = (res.result as Map).map((k, v) => MapEntry(k.toString(), v));
    return map['objectId']?.toString() ?? '';
  }

  static Future<void> resetUserPassword({
    required String userId,
    required String password,
  }) async {
    final fn = ParseCloudFunction('resetUserPassword');
    final res = await fn.execute(parameters: {'userId': userId, 'password': password});
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Erro ao redefinir senha');
    }
  }

  static Future<void> setUserRole({
    required String userId,
    required String role,
  }) async {
    final fn = ParseCloudFunction('setUserRole');
    final res = await fn.execute(parameters: {'userId': userId, 'role': role});
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Erro ao alterar papel');
    }
  }
}

class UserRow {
  final String objectId;
  final String? username;
  final String? name;
  final String? role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserRow({
    required this.objectId,
    this.username,
    this.name,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory UserRow.fromJson(Map<String, dynamic> j) {
    DateTime? _parse(String? s) => (s == null) ? null : DateTime.tryParse(s);
    return UserRow(
      objectId: (j['objectId'] ?? '').toString(),
      username: j['username']?.toString(),
      name: j['name']?.toString(),
      role: j['role']?.toString(),
      createdAt: _parse(j['createdAt']?.toString()),
      updatedAt: _parse(j['updatedAt']?.toString()),
    );
  }
}
