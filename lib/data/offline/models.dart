import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class ProductModel {
  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final String unit;
  final double stock;
  final double minStock;
  final bool active;
  final double price;
  final double cost;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.active,
    required this.price,
    required this.cost,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sku': sku,
    'barcode': barcode,
    'unit': unit,
    'stock': stock,
    'minStock': minStock,
    'active': active,
    'price': price,
    'cost': cost,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ProductModel fromMap(Map<String, dynamic> m) => ProductModel(
    id: m['id'] as String,
    name: (m['name'] ?? '-') as String,
    sku: (m['sku'] ?? '-') as String,
    barcode: m['barcode'] as String?,
    unit: (m['unit'] ?? 'UN') as String,
    stock: (m['stock'] ?? 0).toDouble(),
    minStock: (m['minStock'] ?? 0).toDouble(),
    active: (m['active'] ?? true) as bool,
    price: (m['price'] ?? 0).toDouble(),
    cost: (m['cost'] ?? 0).toDouble(),
    updatedAt: DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Constrói um ParseObject apenas para leitura nas telas (compatível com seu código atual).
  ParseObject toParseObject() {
    final o = ParseObject('Product')..objectId = id;
    o.set<String>('name', name);
    o.set<String>('sku', sku);
    if (barcode != null) o.set<String>('barcode', barcode!);
    o.set<String>('unit', unit);
    o.set<num>('stock', stock);
    o.set<num>('minStock', minStock);
    o.set<bool>('active', active);
    o.set<num>('price', price);
    o.set<num>('cost', cost);
    return o;
  }
}
