// lib/repositories/product_repository.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Repositório de Produtos (Parse)
///
/// Classe: Product
/// Campos utilizados:
/// - sku (String)          // código
/// - name (String)
/// - barcode (String?)
/// - unit (String)
/// - price (Number)
/// - cost (Number)
/// - category (String?)
/// - ncm (String?)
/// - brand (String?)
/// - margin (Number?)      // margem em %
/// - stock (Number)
/// - minStock (Number)
/// - maxStock (Number)
/// - active (Boolean)
/// - image (File?)
class ProductRepository {
  static const String className = 'Product';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  /// Calcula preço a partir de custo + margem (%).
  double priceFromCostAndMargin(double cost, double marginPercent) {
    final m = marginPercent / 100.0;
    if (cost <= 0) return 0.0;
    return double.parse((cost * (1 + m)).toStringAsFixed(2));
  }

  ParseObject _toParseObject({
    String? objectId,
    required String sku,
    required String name,
    String? barcode,
    String unit = 'UN',
    double price = 0,
    double cost = 0,
    String? category,
    String? ncm,
    String? brand,
    double? margin, // %
    double stock = 0,
    double minStock = 0,
    double maxStock = 0,
    bool active = true,
    ParseFileBase? imageFile,
  }) {
    final obj = ParseObject(className);
    if (objectId != null && objectId.isNotEmpty) obj.objectId = objectId;

    obj
      ..set<String>('sku', sku)
      ..set<String>('name', name)
      ..set<String?>('barcode', barcode)
      ..set<String>('unit', unit)
      ..set<num>('price', price)
      ..set<num>('cost', cost)
      ..set<String?>('category', category)
      ..set<String?>('ncm', ncm)
      ..set<String?>('brand', brand)
      ..set<num?>('margin', margin)
      ..set<num>('stock', stock)
      ..set<num>('minStock', minStock)
      ..set<num>('maxStock', maxStock)
      ..set<bool>('active', active);

    if (imageFile != null) obj.set<ParseFileBase>('image', imageFile);
    return obj;
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Cria/atualiza produto.
  // dentro de ProductRepository
  Future<void> upsertProduct({
    String? objectId,
    required String sku,
    required String name,
    String? barcode,
    required String unit,
    required double price,
    required double cost,
    String? category,
    String? ncm,
    String? brand,
    required double margin,
    required double stock,
    required double minStock,
    required double maxStock,
    ParseFileBase? imageFile,
    required bool active,
    int? packQty,           // NOVOS
    double? packPrice,      // NOVOS
  }) async {
    final o = ParseObject('Product');
    if (objectId != null) o.objectId = objectId;
    o
      ..set<String>('sku', sku)
      ..set<String>('name', name)
      ..set<String?>('barcode', barcode)
      ..set<String>('unit', unit)
      ..set<num>('price', price)
      ..set<num>('cost', cost)
      ..set<String?>('category', category)
      ..set<String?>('ncm', ncm)
      ..set<String?>('brand', brand)
      ..set<num>('margin', margin)
      ..set<num>('stock', stock)
      ..set<num>('minStock', minStock)
      ..set<num>('maxStock', maxStock)
      ..set<bool>('active', active);

    if (packQty != null) o.set<num>('packQty', packQty);
    if (packPrice != null) o.set<num>('packPrice', packPrice);

    if (imageFile != null) {
      await imageFile.save();
      o.set<ParseFileBase>('image', imageFile);
    }
    final res = await o.save();
    if (!res.success) {
      throw Exception(res.error?.message ?? 'Falha ao salvar produto');
    }
  }


  /// Busca produto por ID.
  Future<ParseObject?> getById(String objectId) async {
    debugPrint('[ProductRepo] getById $objectId');
    final obj = ParseObject(className)..objectId = objectId;
    final ParseResponse resp = await obj.getObject(objectId);
    debugPrint('[ProductRepo] getById resp success=${resp.success} err=${resp.error?.code}:${resp.error?.message}');
    if (!resp.success) throw Exception(resp.error?.message);
    return resp.result as ParseObject?;
  }

  /// Busca primeiro produto por SKU (ativo por padrão).
  Future<ParseObject?> getBySku(String sku, {bool includeInactive = false}) async {
    debugPrint('[ProductRepo] getBySku "$sku" includeInactive=$includeInactive');
    final q = QueryBuilder(ParseObject(className))..whereEqualTo('sku', sku);
    if (!includeInactive) q.whereEqualTo('active', true);
    final ParseResponse? r = (await q.first()) as ParseResponse?; // pode retornar null em alguns ambientes
    debugPrint('[ProductRepo] getBySku resp success=${r?.success} err=${r?.error?.code}:${r?.error?.message}');
    if (r == null) return null;
    if (!r.success && r.error?.code != 101) throw Exception(r.error?.message);
    return r.result as ParseObject?;
  }

  /// Busca primeiro produto por código de barras (ativo por padrão).
  Future<ParseObject?> getByBarcode(String barcode, {bool includeInactive = false}) async {
    debugPrint('[ProductRepo] getByBarcode "$barcode" includeInactive=$includeInactive');
    final q = QueryBuilder(ParseObject(className))..whereEqualTo('barcode', barcode);
    if (!includeInactive) q.whereEqualTo('active', true);
    final ParseResponse? r = (await q.first()) as ParseResponse?;
    debugPrint('[ProductRepo] getByBarcode resp success=${r?.success} err=${r?.error?.code}:${r?.error?.message}');
    if (r == null) return null;
    if (!r.success && r.error?.code != 101) throw Exception(r.error?.message);
    return r.result as ParseObject?;
  }

  /// Busca 1 produto por qualquer código: tenta SKU exato, depois BARRAS exato,
  /// depois faz um "contains" por nome/sku/barras e retorna o primeiro.
  Future<ParseObject?> findByAnyCode(String term, {bool includeInactive = false}) async {
    final t = term.trim();
    if (t.isEmpty) return null;

    // 1) SKU exato
    final bySku = await getBySku(t, includeInactive: includeInactive);
    if (bySku != null) return bySku;

    // 2) Barras exato
    final byBar = await getByBarcode(t, includeInactive: includeInactive);
    if (byBar != null) return byBar;

    // 3) Fallback: contains (name/sku/barcode)
    final qName  = QueryBuilder(ParseObject(className))..whereContains('name', t, caseSensitive: false);
    final qSku   = QueryBuilder(ParseObject(className))..whereContains('sku', t, caseSensitive: false);
    final qBar   = QueryBuilder(ParseObject(className))..whereContains('barcode', t, caseSensitive: false);

    final root = ParseObject(className);
    final query = QueryBuilder.or(root, [qName, qSku, qBar])
      ..orderByAscending('name')
      ..setLimit(1);
    if (!includeInactive) query.whereEqualTo('active', true);

    final ParseResponse resp = await query.query();
    debugPrint('[ProductRepo] findByAnyCode("$t") resp success=${resp.success} count=${(resp.results ?? []).length} err=${resp.error?.message}');
    if (!resp.success) throw Exception(resp.error?.message ?? 'Erro na busca');
    if ((resp.results ?? []).isEmpty) return null;
    return resp.results!.first as ParseObject;
  }

  /// Verifica se já existe outro produto com o mesmo SKU.
  Future<bool> existsSku(String sku, {String? exceptId}) async {
    final q = QueryBuilder(ParseObject(className))..whereEqualTo('sku', sku);
    if (exceptId != null && exceptId.isNotEmpty) q.whereNotEqualTo('objectId', exceptId);
    q.setLimit(1);
    final ParseResponse r = await q.query();
    final exists = (r.results ?? []).isNotEmpty;
    debugPrint('[ProductRepo] existsSku("$sku") -> $exists');
    return exists;
  }

  /// Verifica se já existe outro produto com o mesmo código de barras.
  Future<bool> existsBarcode(String barcode, {String? exceptId}) async {
    final q = QueryBuilder(ParseObject(className))..whereEqualTo('barcode', barcode);
    if (exceptId != null && exceptId.isNotEmpty) q.whereNotEqualTo('objectId', exceptId);
    q.setLimit(1);
    final ParseResponse r = await q.query();
    final exists = (r.results ?? []).isNotEmpty;
    debugPrint('[ProductRepo] existsBarcode("$barcode") -> $exists');
    return exists;
  }

  /// Exclui via Cloud Function `deleteProduct` (timeout) e, se falhar, faz soft-delete (active=false).
  /// Retorna: true = deletado; false = inativado.
  Future<bool> delete(String objectId) async {
    debugPrint('[ProductRepo] delete start id=$objectId');

    // 1) Tenta Cloud Function
    try {
      final fn = ParseCloudFunction('deleteProduct');
      final ParseResponse resp = await fn
          .execute(parameters: {'productId': objectId})
          .timeout(const Duration(seconds: 8));
      debugPrint('[ProductRepo] cloud resp success=${resp.success} result=${resp.result} err=${resp.error?.code}:${resp.error?.message}');
      if (resp.success) {
        final Map res = (resp.result is Map) ? (resp.result as Map) : <String, dynamic>{};
        if (res['deleted'] == true) return true;
        if (res['softDeleted'] == true) return false;
        return true; // sem flags, assume deletado
      }
    } on TimeoutException {
      debugPrint('[ProductRepo] cloud TIMEOUT -> fallback');
    } catch (e) {
      debugPrint('[ProductRepo] cloud ERROR -> $e -> fallback');
    }

    // 2) Fallback: inativar localmente
    final obj = ParseObject(className)
      ..objectId = objectId
      ..set<bool>('active', false);
    final ParseResponse r2 = await obj.save();
    debugPrint('[ProductRepo] fallback resp success=${r2.success} err=${r2.error?.code}:${r2.error?.message}');
    if (!r2.success) {
      throw Exception(r2.error?.message ?? 'Falha ao inativar produto');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Busca / Listagem
  // ---------------------------------------------------------------------------

  /// Busca por nome, SKU, código de barras ou marca (somente ativos por padrão).
  Future<List<ParseObject>> searchProducts(
      String term, {
        int limit = 50,
        bool includeInactive = false,
      }) async {
    final t = term.trim();
    debugPrint('[ProductRepo] search term="$t" limit=$limit includeInactive=$includeInactive');
    if (t.isEmpty) return [];

    final qName  = QueryBuilder(ParseObject(className))..whereContains('name', t, caseSensitive: false);
    final qSku   = QueryBuilder(ParseObject(className))..whereContains('sku', t, caseSensitive: false);
    final qBar   = QueryBuilder(ParseObject(className))..whereContains('barcode', t, caseSensitive: false);
    final qBrand = QueryBuilder(ParseObject(className))..whereContains('brand', t, caseSensitive: false);

    final root = ParseObject(className);
    final query = QueryBuilder.or(root, [qName, qSku, qBar, qBrand])
      ..orderByAscending('name')
      ..setLimit(limit);
    if (!includeInactive) query.whereEqualTo('active', true);

    final ParseResponse resp = await query.query();
    debugPrint('[ProductRepo] search resp success=${resp.success} count=${(resp.results ?? []).length} err=${resp.error?.message}');
    if (!resp.success) {
      throw Exception('Erro na busca: ${resp.error?.message}');
    }
    return (resp.results ?? []).cast<ParseObject>();
  }

  /// Lista com paginação (por padrão inclui inativos).
  Future<List<ParseObject>> listAll({
    int limit = 100,
    int skip = 0,
    bool includeInactive = true,
    bool orderAsc = true,
    String orderField = 'name',
  }) async {
    debugPrint('[ProductRepo] listAll limit=$limit skip=$skip includeInactive=$includeInactive order=$orderField ${orderAsc ? 'ASC' : 'DESC'}');

    final q = QueryBuilder(ParseObject(className))
      ..setLimit(limit)
      ..setAmountToSkip(skip);

    if (orderAsc) {
      q.orderByAscending(orderField);
    } else {
      q.orderByDescending(orderField);
    }

    if (!includeInactive) q.whereEqualTo('active', true);

    final ParseResponse r = await q.query();
    debugPrint('[ProductRepo] listAll resp success=${r.success} count=${(r.results ?? []).length} err=${r.error?.message}');
    if (!r.success) {
      throw Exception('Erro ao listar: ${r.error?.message}');
    }
    return (r.results ?? []).cast<ParseObject>();
  }

  /// Lista apenas os ativos (atalho).
  Future<List<ParseObject>> listActive({
    int limit = 100,
    int skip = 0,
    bool orderAsc = true,
    String orderField = 'name',
  }) {
    return listAll(
      limit: limit,
      skip: skip,
      includeInactive: false,
      orderAsc: orderAsc,
      orderField: orderField,
    );
  }

  /// Busca por uma lista de IDs.
  Future<List<ParseObject>> getManyByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    debugPrint('[ProductRepo] getManyByIds count=${ids.length}');
    final q = QueryBuilder(ParseObject(className))..whereContainedIn('objectId', ids);
    final ParseResponse r = await q.query();
    debugPrint('[ProductRepo] getManyByIds resp success=${r.success} count=${(r.results ?? []).length} err=${r.error?.message}');
    if (!r.success) throw Exception(r.error?.message);
    return (r.results ?? []).cast<ParseObject>();
  }

  // ---------------------------------------------------------------------------
  // Estoque / utilidades
  // ---------------------------------------------------------------------------

  /// Define o estoque exatamente para `newStock`.
  Future<void> setStock(String objectId, double newStock) async {
    debugPrint('[ProductRepo] setStock id=$objectId -> $newStock');
    final obj = ParseObject(className)
      ..objectId = objectId
      ..set<num>('stock', newStock);
    final ParseResponse r = await obj.save();
    debugPrint('[ProductRepo] setStock resp success=${r.success} err=${r.error?.message}');
    if (!r.success) throw Exception(r.error?.message);
  }

  /// Ajusta o estoque incrementalmente (delta pode ser negativo).
  Future<void> adjustStock(String objectId, double delta) async {
    debugPrint('[ProductRepo] adjustStock id=$objectId delta=$delta');
    final current = await getById(objectId);
    if (current == null) throw Exception('Produto não encontrado');
    final now = _asDouble(current.get<num>('stock'));
    await setStock(objectId, now + delta);
  }
}
