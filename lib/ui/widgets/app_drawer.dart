// lib/ui/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/session.dart';
import '../../core/rbac.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Session.i;

    // Rótulos + ícones + ROTAS que existem no app_router.dart
    final Map<String, _Entry> meta = {
      Pages.stock:          const _Entry('Estoque', Icons.home, '/'),
      Pages.inventoryCount: const _Entry('Contagem de Estoque', Icons.fact_check, '/inventory-count'),
      // Pages.billingSim removido
      // Pages.users removido
      Pages.pdv:            const _Entry('PDV', Icons.point_of_sale, '/pdv'),
      Pages.products:       const _Entry('Produtos', Icons.inventory_2, '/products'),
      Pages.customers:      const _Entry('Clientes', Icons.people, '/customers'),
      Pages.orders:         const _Entry('Pedidos', Icons.receipt_long, '/orders'),
      Pages.reports:        const _Entry('Relatórios', Icons.bar_chart, '/reports'),
      Pages.finance:        const _Entry('Financeiro', Icons.account_balance_wallet, '/finance'),
      Pages.inventory:      const _Entry('Estoque (Lista)', Icons.warehouse, '/stock'),
      Pages.adminUsers:     const _Entry('Admin • Usuários', Icons.admin_panel_settings, '/admin-users'),
      Pages.settings:       const _Entry('Configurações', Icons.settings, '/settings'),
    };

    final order = [
      Pages.stock,
      Pages.inventoryCount,
      // Pages.billingSim removido
      // Pages.users removido
      Pages.pdv,
      Pages.products,
      Pages.customers,
      Pages.orders,
      Pages.reports,
      Pages.finance,
      Pages.inventory,
      Pages.adminUsers,
      Pages.settings,
    ];

    final role = s.profile?.role;
    final isAdmin = role == Roles.admin;
    final List<String> profilePages = List<String>.from(s.profile?.pages ?? const <String>[]);
    final bool hasWildcard = profilePages.contains('*');
    final Set<String> availableKeys = meta.keys.toSet();

    final Set<String> visibleKeys = {
      if (isAdmin || hasWildcard) ...availableKeys
      else ...profilePages.where(availableKeys.contains)
    };

    final entries = [for (final k in order) if (visibleKeys.contains(k)) meta[k]!];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(s.username ?? 'Usuário'),
              subtitle: Text(role ?? 'sem perfil'),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final currentLoc = GoRouterState.of(context).uri.toString();
                  final selected = currentLoc == e.route;
                  return ListTile(
                    leading: Icon(e.icon),
                    title: Text(e.title),
                    selected: selected,
                    onTap: () {
                      if (selected) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(e.route);
                      }
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
  final String route;
  const _Entry(this.title, this.icon, this.route);
}
