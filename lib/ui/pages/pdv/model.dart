// lib/ui/pages/pdv/model.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Model ================================================================
class _PdvItem {
  _PdvItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.imageUrl,
  });
  String? productId;
  String name;
  double qty;
  double unitPrice;
  String? imageUrl;
}
