// lib/ui/shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).uri.toString();

    int indexFromRoute() {
      return [
        '/', '/produtos', '/clientes', '/estoque', '/pedidos', '/faturamento_sim', '/inventario', '/relatorios'
      ].indexOf(route);
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: indexFromRoute().clamp(0, 7),
            onDestinationSelected: (i) {
              final paths = ['/', '/produtos', '/clientes', '/estoque', '/pedidos', '/faturamento_sim', '/inventario', '/relatorios'];
              context.go(paths[i]);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Geral')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Produtos')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Clientes')),
              NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), label: Text('Estoque')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Pedidos')),
              NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('NF Sim')),
              NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), label: Text('Inventário')),
              NavigationRailDestination(icon: Icon(Icons.summarize_outlined), label: Text('Relatórios')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}