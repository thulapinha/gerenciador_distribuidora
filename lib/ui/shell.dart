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
        // Enquanto descobre o usuário, mostra casca básica
        final user = snap.data;
        final isAdmin = (user?.get<String>('role') ?? 'cashier').toLowerCase() == 'admin';

        // Caminhos e destinos conforme papel
        final adminPaths = [
          '/', '/produtos', '/clientes', '/estoque', '/pedidos', '/pdv', '/faturamento_sim', '/inventario', '/relatorios'
        ];
        final cashierPaths = ['/pdv'];

        final paths = isAdmin ? adminPaths : cashierPaths;

        final adminDestinations = const [
          NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Geral')),
          NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Produtos')),
          NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Clientes')),
          NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), label: Text('Estoque')),
          NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Pedidos')),
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
          NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('NF Sim')),
          NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), label: Text('Inventário')),
          NavigationRailDestination(icon: Icon(Icons.summarize_outlined), label: Text('Relatórios')),
          NavigationRailDestination(icon: Icon(Icons.group_outlined), label: Text('Usuários')), // << NOVA
        ];
        final cashierDestinations = const [
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
        ];
        final destinations = isAdmin ? adminDestinations : cashierDestinations;

        // Seleciona item pela rota atual
        String route = GoRouterState.of(context).uri.path; // ex: /pdv
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
