// lib/ui/pages/pdv/model.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// Mantém compatibilidade com seu layout. Campos extras são opcionais.
class _PdvItem {
  _PdvItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.imageUrl,
    String? uom,          // 'UN' | 'CX'
    double? multiplier,   // itens por CX
  })  : uom = (uom ?? 'UN').toUpperCase(),
        multiplier = (multiplier ?? 1);

  String? productId;
  String name;
  double qty;
  double unitPrice;
  String? imageUrl;

  String uom;        // default 'UN'
  double multiplier; // default 1

  double get total => unitPrice * qty;
}
