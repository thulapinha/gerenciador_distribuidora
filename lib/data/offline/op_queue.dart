class OpTypes {
  static const setStock = 'setStock';
  static const adjustStock = 'adjustStock';
  static const deleteProduct = 'deleteProduct';
// (no futuro: createSale, etc.)
}

class OpQueueItem {
  final int key; // chave do Sembast
  final String type;
  final Map<String, dynamic> payload;

  OpQueueItem({required this.key, required this.type, required this.payload});

  static OpQueueItem fromMap(Map<String, dynamic> m) =>
      OpQueueItem(key: m['key'] as int, type: m['type'] as String, payload: Map<String, dynamic>.from(m['payload'] as Map));
}
