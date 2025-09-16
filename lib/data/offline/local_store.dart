import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = '${await getDatabasesPath()}/gerenciador_offline.db';
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, v) async => _createAll(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createPendingOps(db);
          await _ensureSalesPayloadColumn(db);
        }
        if (oldV < 3) {
          await _ensureProductsColumns(db);
        }
      },
    );
    // Hardening para bancos já criados.
    await _ensureSalesPayloadColumn(_db!);
    await _createPendingOps(_db!);
    await _ensureProductsColumns(_db!);
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError(
        'LocalStore não inicializado. Chame LocalStore.instance.init() no main().',
      );
    }
    return d;
  }

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------
  Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id TEXT PRIMARY KEY,
        name TEXT,
        sku TEXT,
        barcode TEXT,
        unit TEXT,
        price REAL,
        cost REAL,
        stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        image_url TEXT,
        updated_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');

    await _createPendingOps(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createPendingOps(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_ops(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,        -- 'stock_delta' | 'stock_set'
        product_id TEXT,
        delta REAL,
        payload TEXT,
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ops_prod ON pending_ops(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ops_status ON pending_ops(status)');
  }

  Future<void> _ensureSalesPayloadColumn(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(sales)');
    bool has(String n) =>
        info.any((c) => (c['name'] as String).toLowerCase() == n);
    if (!has('payload')) {
      await db.execute('ALTER TABLE sales ADD COLUMN payload TEXT');
    }
    if (!has('status')) {
      await db.execute('ALTER TABLE sales ADD COLUMN status TEXT NOT NULL DEFAULT "PENDING"');
    }
    if (!has('created_at')) {
      await db.execute('ALTER TABLE sales ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _ensureProductsColumns(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(products)');
    bool has(String n) =>
        info.any((c) => (c['name'] as String).toLowerCase() == n);

    Future<void> add(String name, String type, String def) async {
      await db.execute('ALTER TABLE products ADD COLUMN $name $type $def');
    }

    if (!has('min_stock')) await add('min_stock', 'REAL', 'DEFAULT 0');
    if (!has('active')) await add('active', 'INTEGER', 'DEFAULT 1');
    if (!has('image_url')) await add('image_url', 'TEXT', '');
    if (!has('updated_at')) await add('updated_at', 'INTEGER', 'DEFAULT 0');
  }

  // ---------------------------------------------------------------------------
  // Produtos
  // ---------------------------------------------------------------------------
  Future<void> upsertProducts(List<Map<String, dynamic>> items) async {
    final b = db.batch();
    for (final p in items) {
      b.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listProducts({
    int? limit,
    bool includeInactive = false,
  }) async {
    final where = includeInactive ? '' : 'WHERE active = 1';
    final lim = (limit != null) ? 'LIMIT $limit' : '';
    return db.rawQuery(
      'SELECT * FROM products $where ORDER BY name ASC $lim',
    );
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final r = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> getBySku(String sku, {bool includeInactive = true}) async {
    final cond = includeInactive ? '1=1' : 'active = 1';
    final r = await db.query(
      'products',
      where: 'LOWER(sku) = LOWER(?) AND $cond',
      whereArgs: [sku],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> getByBarcode(String code, {bool includeInactive = true}) async {
    final cond = includeInactive ? '1=1' : 'active = 1';
    final r = await db.query(
      'products',
      where: 'LOWER(barcode) = LOWER(?) AND $cond',
      whereArgs: [code],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, dynamic>>> searchProducts(
      String term, {
        int limit = 40,
        bool includeInactive = true,
      }) async {
    final t = term.trim();
    if (t.isEmpty) {
      return listProducts(limit: limit, includeInactive: includeInactive);
    }
    final cond = includeInactive ? '1=1' : 'active = 1';
    return db.query(
      'products',
      where:
      '($cond) AND (LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(barcode) LIKE ?)',
      whereArgs: [
        '%${t.toLowerCase()}%',
        '%${t.toLowerCase()}%',
        '%${t.toLowerCase()}%',
      ],
      orderBy: 'name ASC',
      limit: limit,
    );
  }

  Future<void> setStockLocal(String productId, double value) async {
    await db.update('products', {'stock': value}, where: 'id = ?', whereArgs: [productId]);
  }

  Future<void> adjustStockLocal(String productId, double delta) async {
    await db.rawUpdate(
      'UPDATE products SET stock = IFNULL(stock,0) + ? WHERE id = ?',
      [delta, productId],
    );
  }

  Future<void> inactivateLocal(String productId) async {
    await db.update('products', {'active': 0}, where: 'id = ?', whereArgs: [productId]);
  }

  // ---------------------------------------------------------------------------
  // Pendências (ajustes e vendas)
  // ---------------------------------------------------------------------------
  Future<void> queueStockDelta(String productId, double delta) async {
    final id = 'OP${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('pending_ops', {
      'id': id,
      'type': 'stock_delta',
      'product_id': productId,
      'delta': delta,
      'payload': null,
      'status': 'PENDING',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queueStockSet(String productId, double value) async {
    final id = 'OP${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('pending_ops', {
      'id': id,
      'type': 'stock_set',
      'product_id': productId,
      'delta': value,
      'payload': null,
      'status': 'PENDING',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> listPendingOps() async {
    return db.query('pending_ops',
        where: 'status = ?', whereArgs: ['PENDING'], orderBy: 'created_at ASC');
  }

  Future<void> markOpDone(String id) async {
    await db.update('pending_ops', {'status': 'DONE'}, where: 'id = ?', whereArgs: [id]);
  }

  // --- vendas pendentes
  Future<String> queueSale(Map<String, dynamic> payload) async {
    final id = 'S${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('sales', {
      'id': id,
      'payload': jsonEncode(payload),
      'status': 'PENDING',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listPendingSales() async {
    return db.query('sales',
        where: 'status = ?', whereArgs: ['PENDING'], orderBy: 'created_at ASC');
  }

  Future<void> markSaleDone(String id) async {
    await db.update('sales', {'status': 'DONE'}, where: 'id = ?', whereArgs: [id]);
  }

  // Soma delta local pendente (ajustes + vendas)
  Future<double> pendingDeltaFor(String productId) async {
    double total = 0;

    // ajustes
    final ops = await db.query(
      'pending_ops',
      columns: ['delta', 'type'],
      where: 'status = ? AND product_id = ?',
      whereArgs: ['PENDING', productId],
    );
    for (final o in ops) {
      final type = (o['type'] as String?) ?? '';
      final v = (o['delta'] as num?)?.toDouble() ?? 0.0;
      if (type == 'stock_delta') total += v;
      // 'stock_set' já foi aplicado localmente.
    }

    // vendas pendentes
    final sales = await listPendingSales();
    for (final s in sales) {
      final payload = jsonDecode(s['payload'] as String) as Map<String, dynamic>;
      final items = (payload['items'] as List).cast<Map<String, dynamic>>();
      for (final it in items) {
        final pid = it['productId'] as String?;
        if (pid == productId) {
          final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
          total -= qty;
        }
      }
    }

    return total;
  }
}
