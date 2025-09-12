import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/session.dart';
import '../../core/rbac.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.i;

    List<_Entry> all = [
      _Entry('Dashboard', Icons.dashboard, '/', Pages.stock),
      _Entry('PDV', Icons.point_of_sale, '/pdv', Pages.pdv),
      _Entry('Produtos', Icons.inventory_2, '/products', Pages.products),
      _Entry('Clientes', Icons.people, '/customers', Pages.customers),
      _Entry('Pedidos', Icons.shopping_bag, '/orders', Pages.orders),
      _Entry('Financeiro', Icons.attach_money, '/finance', Pages.finance),
      _Entry('Relatórios', Icons.bar_chart, '/reports', Pages.reports),
      _Entry('Usuários (Admin)', Icons.admin_panel_settings, '/admin-users', Pages.adminUsers),
      _Entry('Configurações', Icons.settings, '/settings', Pages.settings),
    ];

    final visible = all.where((e) => s.show(e.pageKey)).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(s.username ?? 'Usuário'),
              subtitle: Text(s.role.isEmpty ? 'Sem papel' : s.role),
              leading: const CircleAvatar(child: Icon(Icons.person)),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) {
                  final e = visible[i];
                  return ListTile(
                    leading: Icon(e.icon),
                    title: Text(e.title),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(e.path);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  final String title;
  final IconData icon;
  final String path;
  final String pageKey;
  _Entry(this.title, this.icon, this.path, this.pageKey);
}
