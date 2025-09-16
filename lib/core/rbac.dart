// lib/core/rbac.dart
import 'dart:convert';

class Roles {
  static const admin = 'admin';
  static const cashier = 'cashier';
  static const stockist = 'stockist';
  static const finance = 'finance';
}

class Pages {
  // chaves devem bater com as do backend (Parse Cloud)

  // existentes
  static const pdv = 'pdv';
  static const customers = 'customers';
  static const products = 'products';
  static const stock = 'stock';            // dashboard de estoque
  static const inventory = 'inventory';
  static const orders = 'orders';
  static const finance = 'finance';
  static const reports = 'reports';
  static const adminUsers = 'adminUsers';
  static const settings = 'settings';

  // NOVAS chaves usadas nas rotas/menus adicionados
  static const billingSim = 'billingSim';          // /billing-sim (Simulador de Cobrança)
  static const inventoryCount = 'inventoryCount';  // /inventory-count (Contagem de Inventário)
  static const stockPage = 'stockPage';            // /stock (itens/gestão de estoque)
  static const users = 'users';                    // /users (lista/gestão de usuários)
}

class Caps {
  static const all = '*';
  static const salesCreate = 'sales.create';
  static const usersManage = 'users.manage';
  static const productDelete = 'product.delete';
  static const productPriceUpdate = 'product.price.update';
  static const productStockUpdate = 'product.stock.update';
  static const productBaseUpdate = 'product.base.update';
  static const customersUpsert = 'customers.upsert';
  static const syncPull = 'sync.pull';
  static const syncPushSales = 'sync.push.sales';
  static const syncPushCustomers = 'sync.push.customers';
  static const syncPushProducts = 'sync.push.products';
  static const financeRead = 'finance.read';
  static const reportsRead = 'reports.read';
}

class AccessProfile {
  final String role;
  final List<String> pages;
  final List<String> caps;

  const AccessProfile({
    required this.role,
    required this.pages,
    required this.caps,
  });

  factory AccessProfile.fromJson(Map<String, dynamic> j) {
    return AccessProfile(
      role: (j['role'] ?? '').toString(),
      pages: (j['pages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      caps: (j['caps'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'pages': pages,
    'caps': caps,
  };

  bool can(String cap) => caps.contains(Caps.all) || caps.contains(cap);
  bool showPage(String page) => pages.contains(page);

  @override
  String toString() => jsonEncode(toJson());
}
