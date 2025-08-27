// lib/data/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ===== Tables ===== //
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text()();
  TextColumn get description => text()();
  TextColumn get ncm => text().withDefault(const Constant('2203.00.00'))();
  TextColumn get unit => text().withDefault(const Constant('UN'))();
}

class Lots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get code => text()();
  DateTimeColumn get expiry => dateTime()();
}

class Warehouses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Stock extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get warehouseId => integer().references(Warehouses, #id)();
  TextColumn get address => text().withDefault(const Constant('PRINCIPAL'))();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get lotId => integer().references(Lots, #id)();
  RealColumn get qty => real().withDefault(const Constant(0.0))();
  RealColumn get reservedQty => real().withDefault(const Constant(0.0))();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cnpjCpf => text()();
  TextColumn get ie => text().nullable()();
  TextColumn get name => text()();
  TextColumn get route => text().withDefault(const Constant('R0'))();
  IntColumn get paymentTermDays => integer().withDefault(const Constant(28))();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
}

class Prices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get value => real()();
}

enum OrderStatus { draft, reserved, billed, cancelled }

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get status => intEnum<OrderStatus>()
      .withDefault(Constant(OrderStatus.draft.index))();
  RealColumn get total => real().withDefault(const Constant(0.0))();
}

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get qty => real()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get bonusQty => real().withDefault(const Constant(0.0))();
}

class Reservations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderItemId => integer().references(OrderItems, #id)();
  IntColumn get lotId => integer().references(Lots, #id)();
  RealColumn get qty => real()();
}

enum TitleStatus { open, settled, cancelled }

class FinancialTitles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get originType => text()(); // 'order' | 'invoice'
  IntColumn get originId => integer()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get value => real()();
  IntColumn get status => intEnum<TitleStatus>()
      .withDefault(Constant(TitleStatus.open.index))();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get ts => dateTime().withDefault(currentDateAndTime)();
  TextColumn get actor => text().withDefault(const Constant('system'))();
  TextColumn get action => text()();
  TextColumn get entity => text()();
  IntColumn get entityId => integer()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
}

@DriftDatabase(
  tables: [
    Products, Lots, Warehouses, Stock, Customers, Prices, Orders,
    OrderItems, Reservations, FinancialTitles, AuditLogs
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override
  int get schemaVersion => 1;

  // Seed básico para testes rápidos
  Future<void> seedIfEmpty() async {
    final pCount = await (select(products)..limit(1)).get();
    if (pCount.isNotEmpty) return;

    final whId = await into(warehouses).insert(
      WarehousesCompanion.insert(name: 'DEPÓSITO PRINCIPAL'),
    );

    final idCerveja = await into(products).insert(
      ProductsCompanion.insert(
        sku: 'CERV001',
        description: 'Cerveja Pilsen 350ml',
        ncm: const Value('2203.00.00'),
        unit: const Value('UN'),
      ),
    );
    await into(prices).insert(
      PricesCompanion.insert(productId: idCerveja, value: 4.50),
    );

    final l1 = await into(lots).insert(
      LotsCompanion.insert(
        productId: idCerveja,
        code: 'L2301',
        expiry: DateTime.now().add(const Duration(days: 45)),
      ),
    );
    final l2 = await into(lots).insert(
      LotsCompanion.insert(
        productId: idCerveja,
        code: 'L2302',
        expiry: DateTime.now().add(const Duration(days: 90)),
      ),
    );

    await into(stock).insert(StockCompanion.insert(
      warehouseId: whId,
      address: const Value('A01-01'),
      productId: idCerveja,
      lotId: l1,
      qty: const Value(200.0),
      reservedQty: const Value(0.0),

    ));
    await into(stock).insert(StockCompanion.insert(
      warehouseId: whId,
      address: const Value('A01-02'),
      productId: idCerveja,
      lotId: l2,
      qty: const Value(500.0),
      reservedQty: const Value(0.0),

    ));

    await into(customers).insert(CustomersCompanion.insert(
      cnpjCpf: '11.222.333/0001-44',
      ie: const Value('ISENTO'),
      name: 'Cliente Teste',
      route: const Value('R1'),
      paymentTermDays: const Value(28),
      creditLimit: const Value(10000.0),
    ));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'gerenciador_distribuidora.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
