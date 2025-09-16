import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/auth_service.dart';
import '../../core/session.dart';

enum _ServerState { unknown, online, offline }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  bool _showPass = false;
  bool _remember = true;

  _ServerState _serverState = _ServerState.unknown;
  int? _latencyMs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    // Tenta pingar o servidor assim que a tela abre
    WidgetsBinding.instance.addPostFrameCallback((_) => _pingServer());
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _remember = sp.getBool('login.remember') ?? true;
      if (_remember) {
        _user.text = sp.getString('login.lastUser') ?? '';
      }
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('login.remember', _remember);
    if (_remember) {
      await sp.setString('login.lastUser', _user.text.trim());
    } else {
      await sp.remove('login.lastUser');
    }
  }

  Future<void> _pingServer() async {
    setState(() {
      _serverState = _ServerState.unknown;
      _latencyMs = null;
    });
    try {
      final t0 = DateTime.now();
      final fn = ParseCloudFunction('serverNow');
      final res = await fn.execute();
      final dt = DateTime.now().difference(t0).inMilliseconds;
      if (res.success) {
        setState(() {
          _serverState = _ServerState.online;
          _latencyMs = dt;
        });
      } else {
        setState(() {
          _serverState = _ServerState.offline;
          _latencyMs = dt;
        });
      }
    } catch (_) {
      setState(() {
        _serverState = _ServerState.offline;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.login(_user.text.trim(), _pass.text.trim());
      await _savePrefs();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid username/password')) {
      return 'Usuário ou senha inválidos.';
    }
    if (msg.contains('network') || msg.contains('xhr') || msg.contains('host lookup')) {
      return 'Falha de conexão. Verifique sua internet/servidor.';
    }
    return raw.replaceAll('Exception:', '').trim();
  }

  Future<void> _resetPassword() async {
    // Requer e-mail habilitado no Parse. Mostramos feedback mesmo se não estiver.
    final username = _user.text.trim();
    if (username.isEmpty || !username.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe seu e-mail no campo usuário para resetar a senha.')),
      );
      return;
    }
    try {
      final res = await ParseUser(null, null, username).requestPasswordReset();
      if (!mounted) return;
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se o e-mail estiver cadastrado, você receberá instruções.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível solicitar reset: ${res.error?.message ?? ''}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao solicitar reset: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo com gradiente sutil
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.black, Colors.teal.shade900]
                    : [Colors.teal.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Conteúdo central
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(serverState: _serverState, latencyMs: _latencyMs, onPing: _pingServer),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),
                      if (_error != null) const SizedBox(height: 8),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _user,
                              focusNode: _userFocus,
                              decoration: const InputDecoration(
                                labelText: 'Usuário ou e-mail',
                                prefixIcon: Icon(Icons.person),
                              ),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _passFocus.requestFocus(),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o usuário' : null,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _pass,
                              focusNode: _passFocus,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  tooltip: _showPass ? 'Ocultar senha' : 'Mostrar senha',
                                  icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                                  onPressed: _loading ? null : () => setState(() => _showPass = !_showPass),
                                ),
                              ),
                              obscureText: !_showPass,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  onChanged: _loading ? null : (v) => setState(() => _remember = v ?? true),
                                ),
                                const Text('Lembrar usuário'),
                                const Spacer(),
                                TextButton(
                                  onPressed: _loading ? null : _resetPassword,
                                  child: const Text('Esqueci a senha'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text('Entrar'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _loading ? null : _pingServer,
                              icon: const Icon(Icons.wifi_tethering),
                              label: const Text('Testar conexão'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Rodapé com info da sessão (se já existir)
          if (Session.i.logged)
            Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Logado como: ${Session.i.username ?? '-'} (${Session.i.role.isEmpty ? 'sem papel' : Session.i.role})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final _ServerState serverState;
  final int? latencyMs;
  final VoidCallback onPing;

  const _Header({
    required this.serverState,
    required this.latencyMs,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;
    switch (serverState) {
      case _ServerState.online:
        dotColor = Colors.green;
        label = latencyMs != null ? 'Online • ${latencyMs}ms' : 'Online';
        break;
      case _ServerState.offline:
        dotColor = Colors.red;
        label = 'Offline';
        break;
      default:
        dotColor = Colors.grey;
        label = 'Verificando...';
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('Servidor: $label'),
        const Spacer(),
        IconButton(
          tooltip: 'Reverificar',
          onPressed: onPing,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
