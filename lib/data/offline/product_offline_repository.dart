import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'local_store.dart';

class ProductOfflineRepository {
  final _store = LocalStore.instance;

  // Converte linha do SQLite para ParseObject (para reusar sua UI atual)
  ParseObject _toParse(Map<String, dynamic> r) {
    final p = ParseObject('Product')..objectId = r['id'] as String?;

    final name = r['name'] as String?;
    if (name != null) p.set<String>('name', name);

    final sku = r['sku'] as String?;
    if (sku != null) p.set<String>('sku', sku);

    final barcode = r['barcode'] as String?;
    if (barcode != null) p.set<String>('barcode', barcode);

    p.set<String>('unit', (r['unit'] as String?) ?? 'UN');
    p.set<num>('price', (r['price'] as num?) ?? 0);
    p.set<num>('cost', (r['cost'] as num?) ?? 0);
    p.set<num>('stock', ((r['stock'] as num?) ?? 0).toDouble());
    p.set<num>('minStock', ((r['min_stock'] as num?) ?? 0).toDouble());

    final activeInt = (r['active'] as int?) ?? 1;
    p.set<bool>('active', activeInt != 0);

    final img = r['image_url'] as String?;
    if (img != null && img.isNotEmpty) {
      p.set<ParseFileBase>('image', ParseFile(null, name: 'image', url: img));
    }
    return p;
  }

  Future<bool> _isOnline() async {
    try {
      final ping = ParseCloudFunction('_noop');
      final r = await ping.execute();
      // Se a chamada existir, consideramos online.
      return r.success || r.error?.code == 1 || r.result != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<ParseObject>> listAll({
    int? limit,
    bool includeInactive = false,
  }) async {
    if (await _isOnline()) {
      try {
        final q = QueryBuilder<ParseObject>(ParseObject('Product'))
          ..orderByAscending('name');
        if (!includeInactive) q.whereEqualTo('active', true);
        if (limit != null) q.setLimit(limit);
        final r = await q.query();
        if (r.success && r.results != null) {
          final rows = <Map<String, dynamic>>[];
          for (final o in r.results!.cast<ParseObject>()) {
            final id = o.objectId!;
            final serverStock = (o.get<num>('stock') ?? 0).toDouble();
            final delta = await _store.pendingDeltaFor(id);
            final effective = serverStock + delta;

            rows.add({
              'id': id,
              'name': o.get<String>('name'),
              'sku': o.get<String>('sku'),
              'barcode': o.get<String>('barcode'),
              'unit': o.get<String>('unit') ?? 'UN',
              'price': (o.get<num>('price') ?? 0).toDouble(),
              'cost': (o.get<num>('cost') ?? 0).toDouble(),
              'stock': effective,
              'min_stock': (o.get<num>('minStock') ?? 0).toDouble(),
              'active': (o.get<bool>('active') ?? true) ? 1 : 0,
              'image_url': o.get<ParseFileBase>('image')?.url,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            });
          }
          await _store.upsertProducts(rows);
        }
      } catch (_) {}
    }
    final local = await _store.listProducts(limit: limit, includeInactive: includeInactive);
    return local.map(_toParse).toList();
  }

  Future<ParseObject?> getBySku(String sku, {bool includeInactive = true}) async {
    if (await _isOnline()) {
      try {
        final q = QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereEqualTo('sku', sku);
        if (!includeInactive) q.whereEqualTo('active', true);
        final r = await q.query();
        if (r.success && r.results != null && r.results!.isNotEmpty) {
          final p = r.results!.first as ParseObject;
          await _store.upsertProducts([
            {
              'id': p.objectId,
              'name': p.get<String>('name'),
              'sku': p.get<String>('sku'),
              'barcode': p.get<String>('barcode'),
              'unit': p.get<String>('unit') ?? 'UN',
              'price': (p.get<num>('price') ?? 0).toDouble(),
              'cost': (p.get<num>('cost') ?? 0).toDouble(),
              'stock': (p.get<num>('stock') ?? 0).toDouble(),
              'min_stock': (p.get<num>('minStock') ?? 0).toDouble(),
              'active': (p.get<bool>('active') ?? true) ? 1 : 0,
              'image_url': p.get<ParseFileBase>('image')?.url,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }
          ]);
          return p;
        }
      } catch (_) {}
    }
    final row = await _store.getBySku(sku, includeInactive: includeInactive);
    return row == null ? null : _toParse(row);
  }

  Future<ParseObject?> getByBarcode(String barcode, {bool includeInactive = true}) async {
    if (await _isOnline()) {
      try {
        final q = QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereEqualTo('barcode', barcode);
        if (!includeInactive) q.whereEqualTo('active', true);
        final r = await q.query();
        if (r.success && r.results != null && r.results!.isNotEmpty) {
          final p = r.results!.first as ParseObject;
          await _store.upsertProducts([
            {
              'id': p.objectId,
              'name': p.get<String>('name'),
              'sku': p.get<String>('sku'),
              'barcode': p.get<String>('barcode'),
              'unit': p.get<String>('unit') ?? 'UN',
              'price': (p.get<num>('price') ?? 0).toDouble(),
              'cost': (p.get<num>('cost') ?? 0).toDouble(),
              'stock': (p.get<num>('stock') ?? 0).toDouble(),
              'min_stock': (p.get<num>('minStock') ?? 0).toDouble(),
              'active': (p.get<bool>('active') ?? true) ? 1 : 0,
              'image_url': p.get<ParseFileBase>('image')?.url,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }
          ]);
          return p;
        }
      } catch (_) {}
    }
    final row = await _store.getByBarcode(barcode, includeInactive: includeInactive);
    return row == null ? null : _toParse(row);
  }

  Future<List<ParseObject>> searchProducts(
      String term, {
        int limit = 40,
        bool includeInactive = true,
      }) async {
    if (await _isOnline()) {
      try {
        final q = QueryBuilder<ParseObject>(ParseObject('Product'))
          ..whereContains('name', term)
          ..orderByAscending('name')
          ..setLimit(limit);
        if (!includeInactive) q.whereEqualTo('active', true);
        final r = await q.query();
        if (r.success && r.results != null) {
          final rows = r.results!.cast<ParseObject>().map((p) {
            return {
              'id': p.objectId,
              'name': p.get<String>('name'),
              'sku': p.get<String>('sku'),
              'barcode': p.get<String>('barcode'),
              'unit': p.get<String>('unit') ?? 'UN',
              'price': (p.get<num>('price') ?? 0).toDouble(),
              'cost': (p.get<num>('cost') ?? 0).toDouble(),
              'stock': (p.get<num>('stock') ?? 0).toDouble(),
              'min_stock': (p.get<num>('minStock') ?? 0).toDouble(),
              'active': (p.get<bool>('active') ?? true) ? 1 : 0,
              'image_url': p.get<ParseFileBase>('image')?.url,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            };
          }).toList();
          await _store.upsertProducts(rows);
        }
      } catch (_) {}
    }
    final local = await _store.searchProducts(term, limit: limit, includeInactive: includeInactive);
    return local.map(_toParse).toList();
  }

  Future<ParseObject?> findByAnyCode(String term, {bool includeInactive = true}) async {
    final t = term.trim();
    if (t.isEmpty) return null;
    return await getBySku(t, includeInactive: includeInactive) ??
        await getByBarcode(t, includeInactive: includeInactive) ??
        (await searchProducts(t, limit: 10, includeInactive: includeInactive))
            .let((list) => list.isNotEmpty ? list.first : null);
  }

  Future<bool> delete(String id) async {
    try {
      final obj = ParseObject('Product')..objectId = id;
      final r = await obj.delete();
      if (r.success) {
        await _store.inactivateLocal(id);
        return true;
      }
    } catch (_) {}
    await _store.inactivateLocal(id);
    return false;
  }

  Future<void> setStock(String productId, double value) async {
    await _store.setStockLocal(productId, value);
    await _store.queueStockSet(productId, value);
  }

  Future<void> adjustStock(String productId, double delta) async {
    await _store.adjustStockLocal(productId, delta);
    await _store.queueStockDelta(productId, delta);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
