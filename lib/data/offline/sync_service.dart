import 'dart:async'; // <— necessário para StreamSubscription
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'local_store.dart';
import 'product_offline_repository.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _store = LocalStore.instance;
  final _repo = ProductOfflineRepository();

  StreamSubscription<ConnectivityResult>? _sub;
  bool _running = false;

  Future<void> start() async {
    await _syncOnce(); // primeira passada
    _sub ??= Connectivity().onConnectivityChanged.listen((e) async {
      if (e != ConnectivityResult.none) {
        await _syncOnce();
      }
    });
  }

  Future<void> _syncOnce() async {
    if (_running) return;
    _running = true;
    try {
      // 1) Envia vendas pendentes
      final sales = await _store.listPendingSales();
      for (final s in sales) {
        final id = s['id'] as String;
        final payload = jsonDecode(s['payload'] as String) as Map<String, dynamic>;
        try {
          final fn = ParseCloudFunction('finalizeSale');
          final r = await fn.execute(parameters: payload);
          if (r.success) {
            await _store.markSaleDone(id);
          }
        } catch (e) {
          debugPrint('[Sync] venda $id falhou: $e');
        }
      }

      // 2) Ajustes pendentes
      final ops = await _store.listPendingOps();
      for (final o in ops) {
        final id = o['id'] as String;
        final type = o['type'] as String;
        final pid = o['product_id'] as String?;
        final delta = (o['delta'] as num?)?.toDouble();

        if (pid == null) {
          await _store.markOpDone(id);
          continue;
        }

        try {
          final resp = await ParseObject('Product').getObject(pid);
          if (resp.success && resp.result != null) {
            final obj = resp.result as ParseObject;
            final server = (obj.get<num>('stock') ?? 0).toDouble();
            double target = server;
            if (type == 'stock_delta') {
              target = server + (delta ?? 0);
            } else if (type == 'stock_set') {
              target = (delta ?? server);
            }
            obj.set<num>('stock', target);
            final save = await obj.save();
            if (save.success) {
              await _store.markOpDone(id);
              await _store.setStockLocal(pid, target);
            }
          }
        } catch (e) {
          debugPrint('[Sync] ajuste $id falhou: $e');
        }
      }

      // 3) Atualiza cache local
      await _repo.listAll(includeInactive: true);
    } catch (e) {
      debugPrint('[Sync] erro: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
