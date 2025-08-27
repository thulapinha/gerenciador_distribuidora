// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'ui/shell.dart';
import 'ui/pages/dashboard_page.dart';
import 'ui/pages/products_page.dart';
import 'ui/pages/customers_page.dart';
import 'ui/pages/stock_page.dart';
import 'ui/pages/orders_page.dart';
import 'ui/pages/billing_sim_page.dart';
import 'ui/pages/pdv_page.dart';
import 'ui/pages/inventory_count_page.dart';
import 'ui/pages/reports_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/produtos', builder: (_, __) => const ProductsPage()),
          GoRoute(path: '/clientes', builder: (_, __) => const CustomersPage()),
          GoRoute(path: '/estoque', builder: (_, __) => const StockPage()),
          GoRoute(path: '/pedidos', builder: (_, __) => const OrdersPage()),
          GoRoute(path: '/pdv', builder: (_, __) => const PdvPage()),
          GoRoute(path: '/faturamento_sim', builder: (_, __) => const BillingSimPage()),
          GoRoute(path: '/inventario', builder: (_, __) => const InventoryCountPage()),
          GoRoute(path: '/relatorios', builder: (_, __) => const ReportsPage()),
        ],
      ),
    ],
  );
}