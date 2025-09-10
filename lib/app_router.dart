// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/shell.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/dashboard_page.dart';
import 'ui/pages/products_page.dart';
import 'ui/pages/customers_page.dart';
import 'ui/pages/stock_page.dart';
import 'ui/pages/orders_page.dart';
import 'ui/pages/billing_sim_page.dart';
import 'ui/pages/inventory_count_page.dart';
import 'ui/pages/reports_page.dart';
import 'ui/pages/pdv_page.dart';
import 'ui/pages/products/product_form_page.dart';

// NOVOS
import 'ui/pages/finance_report_page.dart';
import 'ui/pages/stock_dashboard_page.dart';

import 'domain/services/auth_service.dart';

GoRouter buildRouter() {
  final auth = AuthService();

  return GoRouter(
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/produtos', builder: (_, __) => const ProductsPage()),
          GoRoute(path: '/clientes', builder: (_, __) => const CustomersPage()),
          GoRoute(path: '/estoque', builder: (_, __) => const StockPage()),
          GoRoute(path: '/pedidos', builder: (_, __) => const OrdersPage()),
          GoRoute(path: '/pdv', builder: (_, __) => const PdvPage()),
          GoRoute(path: '/financeiro', builder: (_, __) => const FinanceReportPage()),          // NOVA
          GoRoute(path: '/estoque_dashboard', builder: (_, __) => const StockDashboardPage()), // NOVA
          GoRoute(path: '/faturamento_sim', builder: (_, __) => const BillingSimPage()),
          GoRoute(path: '/inventario', builder: (_, __) => const InventoryCountPage()),
          GoRoute(path: '/relatorios', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/produtos/novo', builder: (_, __) => const ProductFormPage()),
          GoRoute(
            path: '/produtos/editar/:id',
            builder: (context, state) => ProductFormPage(productId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      final location = state.uri.path;
      final loggingIn = location == '/login';

      final user = await auth.currentUser();
      if (user == null && !loggingIn) return '/login';
      if (user != null && loggingIn) {
        final isAdmin = (user.get<String>('role') ?? 'cashier').toLowerCase() == 'admin';
        return isAdmin ? '/' : '/pdv';
      }
      return null;
    },
  );
}
