// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/session.dart';
import 'core/rbac.dart';

import 'ui/shell.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/stock_dashboard_page.dart';
import 'ui/pages/pdv_page.dart';
import 'ui/pages/products_page.dart';
import 'ui/pages/customers_page.dart';
import 'ui/pages/orders_page.dart';
import 'ui/pages/finance_report_page.dart'; // << mudou
import 'ui/pages/reports_page.dart';
import 'ui/pages/admin_users_page.dart';
import 'ui/pages/settings_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: '/login',
    refreshListenable: Session.i, // reagir a login/logout e mudanças de perfil
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (ctx, st) => const LoginPage(),
      ),
      ShellRoute(
        builder: (ctx, st, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (ctx, st) => const StockDashboardPage(),
          ),
          GoRoute(
            path: '/pdv',
            name: 'pdv',
            builder: (ctx, st) => const PdvPage(),
          ),
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (ctx, st) => const ProductsPage(),
          ),
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (ctx, st) => const CustomersPage(),
          ),
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (ctx, st) => const OrdersPage(),
          ),
          GoRoute(
            path: '/finance',
            name: 'finance',
            builder: (ctx, st) => const FinanceReportPage(), // << mudou
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (ctx, st) => const ReportsPage(),
          ),
          GoRoute(
            path: '/admin-users',
            name: 'adminUsers',
            builder: (ctx, st) => const AdminUsersPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (ctx, st) => const SettingsPage(),
          ),
        ],
      ),
    ],
    redirect: (ctx, state) {
      final logged = Session.i.logged;
      final isLogin = state.matchedLocation == '/login';

      if (!logged && !isLogin) return '/login';
      if (logged && isLogin) return '/';

      // Bloqueio por página (rota) conforme perfil
      final loc = state.matchedLocation;
      String? pageKey;
      if (loc == '/pdv') pageKey = Pages.pdv;
      if (loc == '/products') pageKey = Pages.products;
      if (loc == '/customers') pageKey = Pages.customers;
      if (loc == '/orders') pageKey = Pages.orders;
      if (loc == '/finance') pageKey = Pages.finance;
      if (loc == '/reports') pageKey = Pages.reports;
      if (loc == '/admin-users') pageKey = Pages.adminUsers;
      if (loc == '/settings') pageKey = Pages.settings;
      if (loc == '/') pageKey = Pages.stock; // dashboard de estoque

      if (pageKey != null && logged) {
        if (!Session.i.show(pageKey)) {
          // Sem permissão para a página: redireciona ao dashboard
          return '/';
        }
      }

      return null;
    },
  );
}
