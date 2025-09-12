import 'package:flutter/material.dart';
import '../../core/rbac.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  (String, Color) _labelAndColor(String r) {
    switch (r) {
      case Roles.admin:
        return ('Admin', Colors.deepPurple);
      case Roles.cashier:
        return ('Caixa', Colors.blue);
      case Roles.stockist:
        return ('Estoquista', Colors.teal);
      case Roles.finance:
        return ('Financeiro', Colors.green);
      default:
        return ('Sem papel', Colors.grey);
    }
  }
}
