import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('Gerenciador Distribuidora — MVP (FEFO, Pré-venda, Faturamento Simulado)'),
      ),
    );
  }
}