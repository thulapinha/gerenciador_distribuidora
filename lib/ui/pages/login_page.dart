// lib/ui/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gerenciador_distribuidora/domain/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Garante que NUNCA chega texto pré-preenchido
    _userCtl.text = '';
    _passCtl.text = '';
    // Se vier de hot reload, força limpar depois do primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userCtl.clear();
      _passCtl.clear();
      setState(() {}); // atualiza UI
    });
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _userCtl.text.trim();
    final password = _passCtl.text;
    if (username.isEmpty || password.isEmpty) {
      _snack('Informe usuário e senha.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.login(username, password);
      final isAdmin = await _auth.isAdmin();
      if (!mounted) return;
      context.go(isAdmin ? '/' : '/pdv');
    } catch (e) {
      _snack('Falha no login: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Entrar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // IMPORTANTE: desliga autofill/sugestões/correção
                  TextField(
                    controller: _userCtl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Usuário',
                    ),
                    textInputAction: TextInputAction.next,
                    enableSuggestions: false,
                    autocorrect: false,
                    // Desliga autofill do navegador/SO
                    autofillHints: const <String>[],
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passCtl,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Senha',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                      ),
                    ),
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    autofillHints: const <String>[], // desliga autofill
                    onSubmitted: (_) => _submit(),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
