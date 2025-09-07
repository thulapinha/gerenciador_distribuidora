import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart' hide ParseConfig;
import 'parse_config.dart';

Future<void> initParse() async {
  await Parse().initialize(
    ParseConfig.applicationId,
    ParseConfig.serverUrl,
    clientKey: ParseConfig.clientKey,
    autoSendSessionId: true,
    debug: true,
  );

  await _ensureBootstrapAdmin(); // garante o admin sem manter sessão
}

/// Garante que exista um usuário admin (username=admin, senha=123456).
/// Não mantém o usuário logado após criar/verificar.
Future<void> _ensureBootstrapAdmin() async {
  const username = 'ronilson32';
  const password = '878912';
  const email = 'rbcservico32@gmail.com';

  // 1) tenta login: se existir e logar, garante role=admin e sai
  final tryLogin = ParseUser(username, password, null);
  final loginResp = await tryLogin.login();
  if (loginResp.success) {
    final user = loginResp.result as ParseUser;
    if ((user.get<String>('role') ?? 'admin') != 'admin') {
      user.set<String>('role', 'admin');
      await user.save();
    }
    await user.logout(); // nunca manter sessão aqui
    return;
  }

  // 2) se não achou (code 101), tenta criar
  final errCode = loginResp.error?.code;
  if (errCode == 101) {
    final u = ParseUser(username, password, email)
      ..set<String>('role', 'admin')
      ..set<String>('name', 'Administrador');

    // Algumas instâncias exigem e-mail; passamos email e também liberamos o flag.
    final signResp = await u.signUp(allowWithoutEmail: true);
    if (signResp.success) {
      await u.logout(); // garante que não fica logado
      return;
    }

    // Se já existir com outra senha, não há o que fazer sem intervenção
    // (code 202 = username já tomado). Apenas finaliza silenciosamente.
    if (signResp.error?.code == 202) {
      return;
    }

    // Outros erros: lança para você ver no console.
    throw Exception('Falha ao criar admin: ${signResp.error?.message}');
  }

  // Qualquer outro erro de login: apenas ignora (não cria).
}
