import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart' hide ParseConfig;
import 'parse_config.dart';

Future<void> initParse() async {
  await Parse().initialize(
    ParseConfig.applicationId,
    ParseConfig.serverUrl, // ex.: https://parseapi.back4app.com
    clientKey: ParseConfig.clientKey,
    autoSendSessionId: true,
    debug: true,
  );

  // Teste simples de conectividade REST (não depende de headers extras do SDK)
  await _smokeTestServerNow();

  // Opcional: ping de nuvem (para botões "Testar conexão")
  await ParseCloudFunction('ping').execute();

  // Bootstrap admin (não mantém sessão)
  await _ensureBootstrapAdmin();
}

Future<void> _smokeTestServerNow() async {
  final base = ParseConfig.serverUrl.replaceAll(RegExp(r'/+$'), '');
  final url = Uri.parse('$base/functions/serverNow');
  final r = await http.post(
    url,
    headers: {
      'X-Parse-Application-Id': ParseConfig.applicationId,
      'X-Parse-Client-Key': ParseConfig.clientKey,
      'content-type': 'application/json; charset=utf-8',
    },
    body: jsonEncode({}),
  );
  if (r.statusCode != 200 || r.body.isEmpty) {
    throw Exception('SmokeTest falhou: status=${r.statusCode} body="${r.body}"');
  }
}

Future<void> _ensureBootstrapAdmin() async {
  const username = 'ronilson32';
  const password = '878912';
  const email = 'rbcservico32@gmail.com';

  final tryLogin = ParseUser(username, password, null);
  final loginResp = await tryLogin.login();
  if (loginResp.success) {
    final user = loginResp.result as ParseUser;
    if ((user.get<String>('role') ?? 'admin') != 'admin') {
      user.set<String>('role', 'admin');
      await user.save();
    }
    await user.logout();
    return;
  }

  if (loginResp.error?.code == 101) {
    final u = ParseUser(username, password, email)
      ..set<String>('role', 'admin')
      ..set<String>('name', 'Administrador');

    final signResp = await u.signUp(allowWithoutEmail: true);
    if (signResp.success) {
      await u.logout();
      return;
    }
    if (signResp.error?.code == 202) return; // já existe com outra senha
    throw Exception('Falha ao criar admin: ${signResp.error?.message}');
  }
}
