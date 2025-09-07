// lib/ui/pages/users_page.dart
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/domain/services/user_management_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _svc = UserManagementService();
  bool _loading = true;
  List<ParseObject> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = QueryBuilder(ParseUser.forQuery())
        ..orderByAscending('username')
        ..setLimit(500);
      final r = await q.query();
      if (!r.success) throw Exception(r.error?.message);
      _users = (r.results ?? []).cast<ParseObject>();
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openCreate() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _CreateUserDialog());
    if (ok == true) _load();
  }

  Future<void> _resetPassword(ParseObject u) async {
    final newPass = await showDialog<String>(
      context: context,
      builder: (_) => const _AskPasswordDialog(),
    );
    if (newPass == null || newPass.trim().isEmpty) return;
    try {
      await _svc.resetPassword(userId: u.objectId!, newPassword: newPass.trim());
      _snack('Senha alterada para ${u.get<String>('username')}');
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _changeRole(ParseObject u) async {
    final role = await showDialog<String>(
      context: context,
      builder: (_) => _RoleDialog(current: (u.get<String>('role') ?? 'cashier')),
    );
    if (role == null) return;
    try {
      await _svc.setRole(userId: u.objectId!, role: role);
      _snack('Papel atualizado.');
      _load();
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final u = _users[i];
            return ListTile(
              title: Text(u.get<String>('username') ?? '-'),
              subtitle: Text('Papel: ${(u.get<String>('role') ?? 'cashier').toUpperCase()}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  // ÍCONE CORRIGIDO + sem const
                  IconButton(
                    tooltip: 'Alterar papel',
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    onPressed: () => _changeRole(u),
                  ),
                  IconButton(
                    tooltip: 'Resetar senha',
                    icon: Icon(Icons.lock_reset),
                    onPressed: () => _resetPassword(u),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'cashier';
  final _name = TextEditingController();
  final _svc = UserManagementService();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.createUser(
        username: _username.text.trim(),
        password: _password.text,
        role: _role,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo usuário'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Usuário *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Senha *'),
              obscureText: true,
              validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('Caixa (PDV)')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'cashier'),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Papel'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Criar'),
        ),
      ],
    );
  }
}

class _AskPasswordDialog extends StatefulWidget {
  const _AskPasswordDialog();

  @override
  State<_AskPasswordDialog> createState() => _AskPasswordDialogState();
}

class _AskPasswordDialogState extends State<_AskPasswordDialog> {
  final _pass = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova senha'),
      content: TextField(
        controller: _pass,
        obscureText: true,
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Senha'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _pass.text), child: const Text('Definir')),
      ],
    );
  }
}

class _RoleDialog extends StatelessWidget {
  final String current;
  const _RoleDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    String role = current;
    return StatefulBuilder(builder: (context, setLocal) {
      return AlertDialog(
        title: const Text('Alterar papel'),
        content: DropdownButtonFormField<String>(
          value: role,
          items: const [
            DropdownMenuItem(value: 'cashier', child: Text('Caixa (PDV)')),
            DropdownMenuItem(value: 'admin', child: Text('Administrador')),
          ],
          onChanged: (v) => setLocal(() => role = v ?? role),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, role), child: const Text('Salvar')),
        ],
      );
    });
  }
}
