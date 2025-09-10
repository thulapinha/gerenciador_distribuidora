// lib/ui/shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/domain/services/auth_service.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return FutureBuilder<ParseUser?>(
      future: auth.currentUser(),
      builder: (context, snap) {
        final user = snap.data;
        final isAdmin = (user?.get<String>('role') ?? 'cashier').toLowerCase() == 'admin';

        // *** ATENÇÃO: número de paths == número de destinations ***
        final adminPaths = <String>[
          '/',                   // Geral
          '/produtos',           // Produtos
          '/clientes',           // Clientes
          '/estoque',            // Estoque
          '/pedidos',            // Pedidos
          '/pdv',                // PDV
          '/financeiro',         // NOVO: Relatório Financeiro
          '/estoque_dashboard',  // NOVO: Dashboard de Estoque
          '/faturamento_sim',    // NF Sim
          '/inventario',         // Inventário
          '/relatorios',         // Relatórios
        ];
        final cashierPaths = <String>['/pdv'];

        final paths = isAdmin ? adminPaths : cashierPaths;

        final adminDestinations = const <NavigationRailDestination>[
          NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Geral')),
          NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Produtos')),
          NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Clientes')),
          NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), label: Text('Estoque')),
          NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Pedidos')),
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
          NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('Financeiro')),
          NavigationRailDestination(icon: Icon(Icons.stacked_bar_chart_outlined), label: Text('Dash. Estoque')),
          NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('NF Sim')),
          NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), label: Text('Inventário')),
          NavigationRailDestination(icon: Icon(Icons.summarize_outlined), label: Text('Relatórios')),
        ];
        final cashierDestinations = const <NavigationRailDestination>[
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
        ];
        final destinations = isAdmin ? adminDestinations : cashierDestinations;

        String route = GoRouterState.of(context).uri.path;
        int idx = paths.indexOf(route);
        if (idx < 0) idx = 0;

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: idx.clamp(0, paths.length - 1),
                onDestinationSelected: (i) => context.go(paths[i]),
                labelType: NavigationRailLabelType.all,
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
