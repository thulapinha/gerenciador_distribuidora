// lib/repositories/customer_repository.dart
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class CustomerRepository {
  static const _className = 'Customer';

  Future<ParseObject> upsert({
    String? objectId,
    required String name,
    String? cpf, // para NF Sim
    String? phone,
    String? email,
    String? address,
  }) async {
    final o = ParseObject(_className);
    if (objectId != null) o.objectId = objectId;
    o
      ..set<String>('name', name)
      ..set<String?>('cpf', cpf)
      ..set<String?>('phone', phone)
      ..set<String?>('email', email)
      ..set<String?>('address', address);
    final r = await o.save();
    if (!r.success) throw Exception(r.error?.message);
    return o;
  }

  Future<List<ParseObject>> list({int limit = 200}) async {
    final q = QueryBuilder(ParseObject(_className))
      ..orderByAscending('name')
      ..setLimit(limit);
    final r = await q.query();
    if (!r.success) throw Exception(r.error?.message);
    return (r.results ?? []).cast<ParseObject>();
  }

  Future<void> delete(String id) async {
    final o = ParseObject(_className)..objectId = id;
    final r = await o.delete();
    if (!r.success) throw Exception(r.error?.message);
  }
}
