import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Serviço simples para assinar LiveQuery de Product.
/// Certifique-se de ter LiveQuery habilitado no Back4App.
class LiveQueryService {
  LiveQuery? _liveQuery;

  /// Assina alterações na classe Product.
  /// [onUpdate] é chamado com a lista de objetos que chegaram por evento.
  Future<Subscription<ParseObject>> subscribeProducts(
      void Function(List<ParseObject> objects) onUpdate,
      ) async {
    // Instância do LiveQuery
    _liveQuery ??= LiveQuery();

    // Query
    final query = QueryBuilder<ParseObject>(ParseObject('Product'));

    // Assina — IMPORTANTE: await no subscribe
    final sub = await _liveQuery!.client.subscribe(query);

    // Eventos
    sub.on(LiveQueryEvent.create, (obj) => onUpdate([obj]));
    sub.on(LiveQueryEvent.update, (obj) => onUpdate([obj]));
    sub.on(LiveQueryEvent.enter,  (obj) => onUpdate([obj]));
    // você pode adicionar delete/leave se quiser

    return sub;
  }

  /// Cancela a assinatura (opcional)
  Future<void> unsubscribe(Subscription<ParseObject> sub) async {
    if (_liveQuery != null) {
      _liveQuery!.client.unSubscribe(sub);
    }
  }
}
