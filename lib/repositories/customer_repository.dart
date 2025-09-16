import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class CustomerRepository {
  static const _class = 'Customer';

  QueryBuilder<ParseObject> _baseQuery({bool? onlyActive}) {
    final q = QueryBuilder<ParseObject>(ParseObject(_class));
    q.orderByAscending('name');
    if (onlyActive == true) q.whereEqualTo('active', true);
    return q;
  }

  Future<List<ParseObject>> search({
    String q = '',
    int limit = 50,
    int skip = 0,
    bool onlyActive = true,
  }) async {
    final query = _baseQuery(onlyActive: onlyActive)..setLimit(limit)..setAmountToSkip(skip);

    if (q.trim().isNotEmpty) {
      final term = q.trim();
      // Busca por name / cpfCnpj / phone / email (OR)
      final ors = [
        QueryBuilder<ParseObject>(ParseObject(_class))..whereContains('name', term, caseSensitive: false),
        QueryBuilder<ParseObject>(ParseObject(_class))..whereContains('cpfCnpj', term, caseSensitive: false),
        QueryBuilder<ParseObject>(ParseObject(_class))..whereContains('phone', term, caseSensitive: false),
        QueryBuilder<ParseObject>(ParseObject(_class))..whereContains('email', term, caseSensitive: false),
      ];
      final main = QueryBuilder.or(ParseObject(_class), ors);
      if (onlyActive) main.whereEqualTo('active', true);
      main.orderByAscending('name');
      main.setLimit(limit);
      main.setAmountToSkip(skip);
      final r = await main.query();
      if (!r.success || r.results == null) return [];
      return List<ParseObject>.from(r.results!);
    }

    final res = await query.query();
    if (!res.success || res.results == null) return [];
    return List<ParseObject>.from(res.results!);
  }

  Future<ParseObject?> getById(String id) async {
    final res = await ParseObject(_class).getObject(id);
    if (!res.success || res.result == null) return null;
    return res.result as ParseObject;
  }

  /// Salva (cria/edita). Retorna objectId.
  Future<String> save(Map<String, dynamic> data) async {
    final obj = ParseObject(_class);
    if (data['objectId'] != null) obj.objectId = data['objectId'] as String;

    // Campos padrão
    obj.set<String?>('name', data['name']);
    obj.set<String?>('cpfCnpj', data['cpfCnpj']);
    obj.set<String?>('phone', data['phone']);
    obj.set<String?>('email', data['email']);
    obj.set<String?>('zip', data['zip']);
    obj.set<String?>('street', data['street']);
    obj.set<String?>('number', data['number']);
    obj.set<String?>('neighborhood', data['neighborhood']);
    obj.set<String?>('city', data['city']);
    obj.set<String?>('state', data['state']);
    obj.set<bool>('active', data['active'] ?? true);
    obj.set<num?>('creditLimit', data['creditLimit']);
    obj.set<num?>('balance', data['balance']);
    obj.set<String?>('notes', data['notes']);

    final res = await obj.save();
    if (!res.success || res.result == null) {
      throw res.error?.message ?? 'Falha ao salvar cliente';
    }
    return (res.result as ParseObject).objectId!;
  }

  /// Exclusão lógica por padrão (active=false). Passe [hardDelete]=true para excluir do Parse.
  Future<void> delete(String id, {bool hardDelete = false}) async {
    if (hardDelete) {
      final res = await ParseObject(_class).delete(id: id);
      if (!res.success) throw res.error?.message ?? 'Falha ao excluir';
      return;
    }
    final obj = ParseObject(_class)..objectId = id..set<bool>('active', false);
    final res = await obj.save();
    if (!res.success) throw res.error?.message ?? 'Falha ao inativar';
  }
}
