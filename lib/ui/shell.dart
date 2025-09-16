// lib/ui/shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/app_drawer.dart';
import '../core/session.dart';
import 'widgets/role_badge.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final session = Session.i;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador Distribuidora'),
        actions: [
          if (session.logged)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: RoleBadge(role: session.role)),
            ),
          if (session.logged)
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sair'),
                    content: const Text('Deseja encerrar a sessão?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
                    ],
                  ),
                );
                if (ok == true) {
                  // Se preferir, chame seu AuthService.logout() aqui.
                  await Session.i.clear();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(child: child),
    );
  }
}
