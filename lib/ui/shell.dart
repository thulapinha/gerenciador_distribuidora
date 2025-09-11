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

        // IMPORTANTÍSSIMO: paths e destinations com MESMO tamanho
        final adminPaths = <String>[
          '/estoque_dashboard', // PRIMEIRO: Dashboard de Estoque
          '/pdv',
          '/produtos',
          '/clientes',
          '/estoque',
          '/pedidos',
          '/financeiro',
          '/faturamento_sim',
          '/inventario',
          '/relatorios',
        ];

        final adminDestinations = const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.stacked_bar_chart_outlined),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
          NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Produtos')),
          NavigationRailDestination(icon: Icon(Icons.people_alt_outlined), label: Text('Clientes')),
          NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), label: Text('Estoque')),
          NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Pedidos')),
          NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('Financeiro')),
          NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('NF Sim')),
          NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), label: Text('Inventário')),
          NavigationRailDestination(icon: Icon(Icons.summarize_outlined), label: Text('Relatórios')),
        ];

        final cashierPaths = <String>['/pdv'];
        final cashierDestinations = const <NavigationRailDestination>[
          NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('PDV')),
        ];

        final paths = isAdmin ? adminPaths : cashierPaths;
        final destinations = isAdmin ? adminDestinations : cashierDestinations;

        // Seleciona o índice pelo path atual
        String route = GoRouterState.of(context).uri.path;
        int idx = paths.indexOf(route);
        if (idx < 0) idx = 0;
        if (idx >= paths.length) idx = paths.length - 1;

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: SizedBox(
                  width: 90,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rail = NavigationRail(
                        selectedIndex: idx,
                        onDestinationSelected: (i) => context.go(paths[i]),
                        labelType: NavigationRailLabelType.all,
                        destinations: destinations,
                      );
                      // Rail rolável = sem overflow em telas menores
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(child: rail),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: (snap.connectionState == ConnectionState.waiting)
                    ? const _ShellLoading()
                    : child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShellLoading extends StatelessWidget {
  const _ShellLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      color: cs.surface,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }
}
