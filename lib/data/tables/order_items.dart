import 'package:drift/drift.dart';

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer()(); // Orders.id
  IntColumn get productId => integer()(); // Products.id
  RealColumn get qty => real().withDefault(const Constant(0.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
}
