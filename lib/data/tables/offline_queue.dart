// lib/data/tables/offline_queue.dart
// ignore_for_file: constant_identifier_names
import 'package:drift/drift.dart';

enum QueueStatus { PENDING, SENDING, DONE, ERROR }

class QueueStatusConverter extends TypeConverter<QueueStatus, String> {
  const QueueStatusConverter();
  @override
  QueueStatus fromSql(String fromDb) {
    return QueueStatus.values.firstWhere(
          (e) => e.name == fromDb,
      orElse: () => QueueStatus.PENDING,
    );
  }
  @override
  String toSql(QueueStatus value) => value.name;
}

class OfflineQueue extends Table {
  TextColumn get id => text()(); // UUID (também é o clientTxnId para vendas)
  TextColumn get type => text()(); // 'sale' | 'customer' | 'product'
  TextColumn get op => text()(); // 'create' | 'update' | 'delete'
  TextColumn get payload => text()(); // JSON
  TextColumn get status =>
      text().map(const QueueStatusConverter()).withDefault(const Constant('PENDING'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get tsLocal => text()(); // ISO
  IntColumn get priority => integer().withDefault(const Constant(100))();
  @override
  Set<Column> get primaryKey => {id};
}
