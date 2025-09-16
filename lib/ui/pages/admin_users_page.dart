// lib/ui/pages/admin_users_page.dart
import 'package:flutter/material.dart';
import '../../core/session.dart';
import '../../core/rbac.dart';
import '../../domain/services/auth_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<UserRow>> _future;
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  String _role = Roles.cashier;

  @override
  void initState() {
    super.initState();
    _future = AuthService.listUsers();
  }

  void _reload() {
    setState(() {
      _future = AuthService.listUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.i.can(Caps.usersManage)) {
      return const Center(child: Text('Acesso negado'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Criar usuário', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(labelText: 'Nome (opcional)'),
                          ),
                          TextFormField(
                            controller: _username,
                            decoration: const InputDecoration(labelText: 'Username'),
                            validator: (v) => (v == null || v.isEmpty) ? 'Informe o username' : null,
                          ),
                          TextFormField(
                            controller: _password,
                            decoration: const InputDecoration(labelText: 'Senha'),
                            obscureText: true,
                            validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _role,
                            items: const [
                              DropdownMenuItem(value: Roles.cashier, child: Text('Caixa')),
                              DropdownMenuItem(value: Roles.stockist, child: Text('Estoquista')),
                              DropdownMenuItem(value: Roles.finance, child: Text('Financeiro')),
                              DropdownMenuItem(value: Roles.admin, child: Text('Admin')),
                            ],
                            onChanged: (v) => setState(() => _role = v ?? Roles.cashier),
                            decoration: const InputDecoration(labelText: 'Papel'),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;
                                try {
                                  final id = await AuthService.createUser(
                                    username: _username.text.trim(),
                                    password: _password.text.trim(),
                                    role: _role,
                                    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Usuário criado: $id')),
                                  );
                                  _username.clear();
                                  _password.clear();
                                  _name.clear();
                                  _role = Roles.cashier;
                                  _reload();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro: $e')),
                                  );
                                }
                              },
                              child: const Text('Criar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Usuários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(onPressed: _reload, tooltip: 'Recarregar', icon: const Icon(Icons.refresh)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: FutureBuilder<List<UserRow>>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return Center(child: Text('Erro: ${snap.error}'));
                          }
                          final rows = snap.data ?? const [];
                          if (rows.isEmpty) {
                            return const Center(child: Text('Nenhum usuário encontrado'));
                          }
                          return ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final u = rows[i];
                              return _UserTile(
                                user: u,
                                onChanged: _reload,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  final UserRow user;
  final VoidCallback onChanged;
  const _UserTile({required this.user, required this.onChanged});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  final _newPass = TextEditingController();
  String _newRole = Roles.cashier;

  @override
  void initState() {
    super.initState();
    _newRole = widget.user.role ?? Roles.cashier;
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return ListTile(
      title: Text(u.username ?? '(sem username)'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nome: ${u.name ?? '-'}'),
          Text('Papel: ${u.role ?? '-'}'),
          Text('Criado: ${u.createdAt ?? '-'}'),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: TextField(
              controller: _newPass,
              obscureText: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Nova senha',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: () async {
              if (_newPass.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a nova senha')));
                return;
              }
              try {
                await AuthService.resetUserPassword(userId: u.objectId, password: _newPass.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada')));
                _newPass.clear();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
            },
            child: const Text('Redefinir senha'),
          ),
          DropdownButton<String>(
            value: _newRole,
            items: const [
              DropdownMenuItem(value: Roles.cashier, child: Text('Caixa')),
              DropdownMenuItem(value: Roles.stockist, child: Text('Estoquista')),
              DropdownMenuItem(value: Roles.finance, child: Text('Financeiro')),
              DropdownMenuItem(value: Roles.admin, child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _newRole = v ?? Roles.cashier),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await AuthService.setUserRole(userId: u.objectId, role: _newRole);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Papel atualizado')));
                widget.onChanged();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
            },
            child: const Text('Salvar papel'),
          ),
        ],
      ),
    );
  }
}
