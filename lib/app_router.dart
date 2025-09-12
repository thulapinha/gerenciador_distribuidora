// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'core/rbac.dart';

import 'ui/shell.dart'; // ShellScaffold
import 'ui/pages/login_page.dart';
import 'ui/pages/stock_dashboard_page.dart';
import 'ui/pages/stock_page.dart';
import 'ui/pages/pdv_page.dart';
import 'ui/pages/products_page.dart';
import 'ui/pages/customers_page.dart';
import 'ui/pages/orders_page.dart';
import 'ui/pages/finance_report_page.dart';
import 'ui/pages/reports_page.dart';
import 'ui/pages/admin_users_page.dart';
import 'ui/pages/users_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/billing_sim_page.dart';
import 'ui/pages/inventory_count_page.dart';

GoRouter buildRouter() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const StockDashboardPage(),
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockPage(),
          ),
          // *** Contagem de Estoque ***
          GoRoute(
            path: '/inventory-count',
            builder: (context, state) => const InventoryCountPage(),
          ),
          GoRoute(
            path: '/billing-sim',
            builder: (context, state) => const BillingSimPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: '/pdv',
            builder: (context, state) => const PdvPage(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsPage(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersPage(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceReportPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/admin-users',
            builder: (context, state) => const AdminUsersPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final session = Session.i;
      final logged   = session.logged;
      final loc      = state.uri.toString();
      final role     = session.profile?.role;
      final pages    = List<String>.from(session.profile?.pages ?? const <String>[]);

      // login flow
      if (!logged && loc != '/login') return '/login';
      if (logged && loc == '/login') return '/';

      // RBAC: se admin, **nunca bloqueia**
      final isAdmin = role == Roles.admin;
      if (isAdmin) return null;

      // Se profile tem wildcard, **não bloqueia**
      final hasWildcard = pages.contains('*');
      if (hasWildcard) return null;

      // Mapear rota -> chave Pages.*
      String? pageKey;
      if (loc == '/pdv') pageKey = Pages.pdv;
      if (loc == '/products') pageKey = Pages.products;
      if (loc == '/customers') pageKey = Pages.customers;
      if (loc == '/orders') pageKey = Pages.orders;
      if (loc == '/finance') pageKey = Pages.finance;
      if (loc == '/reports') pageKey = Pages.reports;
      if (loc == '/inventory-count') pageKey = Pages.inventoryCount; // << contagem
      if (loc == '/billing-sim') pageKey = Pages.billingSim;
      if (loc == '/users') pageKey = Pages.users;
      if (loc == '/admin-users') pageKey = Pages.adminUsers;
      if (loc == '/settings') pageKey = Pages.settings;
      if (loc == '/stock') pageKey = Pages.inventory; // lista estoque
      if (loc == '/') pageKey = Pages.stock;          // dashboard estoque

      if (pageKey != null && logged) {
        // usa a regra central do profile
        final allowed = session.show(pageKey);
        if (!allowed) return '/'; // sem permissão -> dashboard
      }

      return null;
    },
  );

  return router;
}
