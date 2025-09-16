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

// Formulário de cliente
import 'ui/pages/customers/customer_form_page.dart';

GoRouter buildRouter() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),

      // Tudo o que fica “dentro” do shell da sua UI
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/',                builder: (context, state) => const StockDashboardPage()),
          GoRoute(path: '/stock',           builder: (context, state) => const StockPage()),
          GoRoute(path: '/inventory-count', builder: (context, state) => const InventoryCountPage()),
          GoRoute(path: '/billing-sim',     builder: (context, state) => const BillingSimPage()),
          GoRoute(path: '/users',           builder: (context, state) => const UsersPage()),
          GoRoute(path: '/pdv',             builder: (context, state) => const PdvPage()),
          GoRoute(path: '/products',        builder: (context, state) => const ProductsPage()),

          // ===== Clientes (lista + filhos) =====
          GoRoute(
            path: '/customers',
            name: 'customerList',
            builder: (context, state) => const CustomersPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'customerNew',
                builder: (context, state) => const CustomerFormPage(),
              ),
              GoRoute(
                path: ':id',
                name: 'customerEdit',
                builder: (context, state) =>
                    CustomerFormPage(customerId: state.pathParameters['id']),
              ),
            ],
          ),

          // ===== Aliases PT-BR =====
          GoRoute(path: '/clientes',        redirect: (_, __) => '/customers'),
          GoRoute(path: '/clientes/novo',   redirect: (_, __) => '/customers/new'),
          GoRoute(path: '/clientes/:id',    redirect: (ctx, st) => '/customers/${st.pathParameters['id']}'),
          // muitos usuários usam /clientes/editar/:id — cobre isso também
          GoRoute(path: '/clientes/editar/:id', redirect: (ctx, st) => '/customers/${st.pathParameters['id']}'),

          GoRoute(path: '/orders',       builder: (context, state) => const OrdersPage()),
          GoRoute(path: '/finance',      builder: (context, state) => const FinanceReportPage()),
          GoRoute(path: '/reports',      builder: (context, state) => const ReportsPage()),
          GoRoute(path: '/admin-users',  builder: (context, state) => const AdminUsersPage()),
          GoRoute(path: '/settings',     builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],

    // ===== REDIRECT / RBAC ==================================================
    redirect: (context, state) {
      final session = Session.i;
      final logged   = session.logged;
      final loc      = state.uri.toString();
      final role     = session.profile?.role;
      final pages    = List<String>.from(session.profile?.pages ?? const <String>[]);

      // login flow
      if (!logged && loc != '/login') return '/login';
      if (logged && loc == '/login') return '/';

      // Admin libera tudo
      final isAdmin = role == Roles.admin;
      if (isAdmin) return null;

      // Wildcard libera tudo
      final hasWildcard = pages.contains('*');
      if (hasWildcard) return null;

      // RBAC por prefixo de rota
      String? pageKey;
      if (loc.startsWith('/pdv')) pageKey = Pages.pdv;
      if (loc.startsWith('/products')) pageKey = Pages.products;
      if (loc.startsWith('/customers') || loc.startsWith('/clientes')) pageKey = Pages.customers;
      if (loc.startsWith('/orders')) pageKey = Pages.orders;
      if (loc.startsWith('/finance')) pageKey = Pages.finance;
      if (loc.startsWith('/reports')) pageKey = Pages.reports;
      if (loc.startsWith('/inventory-count')) pageKey = Pages.inventoryCount;
      if (loc.startsWith('/billing-sim')) pageKey = Pages.billingSim;
      if (loc.startsWith('/users')) pageKey = Pages.users;
      if (loc.startsWith('/admin-users')) pageKey = Pages.adminUsers;
      if (loc.startsWith('/settings')) pageKey = Pages.settings;
      if (loc.startsWith('/stock')) pageKey = Pages.inventory; // lista de estoque
      if (loc == '/') pageKey = Pages.stock;                   // dashboard de estoque

      if (pageKey != null && logged) {
        final allowed = session.show(pageKey);
        if (!allowed) return '/';
      }
      return null;
    },
  );

  return router;
}
