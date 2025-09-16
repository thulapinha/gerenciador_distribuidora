import 'package:flutter/material.dart';
import 'package:gerenciador_distribuidora/domain/services/pdf_service.dart';

class CashReportScreen extends StatelessWidget {
  /// Estrutura esperada: { summary, sales, movements }
  final Map<String, dynamic> report;
  const CashReportScreen({super.key, required this.report});

  String _money(num v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final summary = Map<String, dynamic>.from(report['summary'] ?? {});
    final sales = List<Map<String, dynamic>>.from(report['sales'] ?? []);
    final moves = List<Map<String, dynamic>>.from(report['movements'] ?? []);
    final totals = Map<String, dynamic>.from(summary['totals'] ?? {});
    final byMethod = Map<String, dynamic>.from(totals['byMethod'] ?? {});

    final openingAmount =
    (summary['openingAmount'] is num) ? summary['openingAmount'] as num : 0;
    final declared =
    (summary['declaredClosingAmount'] is num) ? summary['declaredClosingAmount'] as num : 0;
    final expectedCash =
    (summary['expectedCash'] is num) ? summary['expectedCash'] as num : 0;
    final difference =
    (summary['difference'] is num) ? summary['difference'] as num : 0;

    final diffColor = difference == 0
        ? Colors.green
        : (difference > 0 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato do Caixa'),
        actions: [
          IconButton(
            tooltip: 'Imprimir',
            onPressed: () {
              PdfService.printCashboxReport(
                context,
                summary: summary,
                sales: sales,
                movements: moves,
              );
            },
            icon: const Icon(Icons.print),
          ),
          IconButton(
            tooltip: 'Salvar/Compartilhar PDF',
            onPressed: () {
              PdfService.shareCashboxReport(
                summary: summary,
                sales: sales,
                movements: moves,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sessão: ${summary['sessionId'] ?? '-'}'),
                  Text('Operador: ${summary['operatorId'] ?? '-'}'),
                  Text('Status: ${(summary['status'] ?? '-').toString().toUpperCase()}'),
                  Text('Abertura: ${summary['openedAt'] ?? '-'}'),
                  Text('Fechamento: ${summary['closedAt'] ?? '-'}'),
                  const Divider(),
                  Text('Troco inicial: ${_money(openingAmount)}'),
                  Text('Declarado no fechamento: ${_money(declared)}'),
                  Text('Esperado em caixa: ${_money(expectedCash)}'),
                  Text(
                    'Diferença: ${_money(difference)}',
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Totais', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Bruto: ${_money((totals['gross'] ?? 0) as num)}'),
                  Text('Desconto: ${_money((totals['discount'] ?? 0) as num)}'),
                  Text('Líquido: ${_money((totals['net'] ?? 0) as num)}'),
                  const SizedBox(height: 8),
                  const Text('Por método de pagamento:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...byMethod.entries.map((e) {
                    final m = Map<String, dynamic>.from(e.value as Map);
                    final cnt = (m['count'] ?? 0) as num;
                    final tot = (m['total'] ?? 0) as num;
                    final rec = (m['received'] ?? 0) as num;
                    final tro = (m['change'] ?? 0) as num;
                    return Text(
                      '${e.key}: cnt=$cnt, tot=${_money(tot)}, rec=${_money(rec)}, troco=${_money(tro)}',
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('SUPRIMENTO: ${_money((totals['cashIn'] ?? 0) as num)}'),
                  Text('SANGRIA: ${_money((totals['cashOut'] ?? 0) as num)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vendas', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (sales.isEmpty)
                    const Text('Nenhuma venda no período.')
                  else
                    ...sales.map((s) {
                      final total = (s['total'] ?? 0) as num;
                      final subtotal = (s['subtotal'] ?? 0) as num;
                      final discount = (s['discount'] ?? 0) as num;
                      return ListTile(
                        dense: true,
                        title: Text('Nº ${s['number'] ?? s['objectId']} - ${s['paymentMethod']}'),
                        subtitle: Text(
                          'Data: ${s['createdAt']}  '
                              'Total: ${_money(total)} (bruto ${_money(subtotal)}, desc ${_money(discount)})',
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Movimentos de Caixa', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (moves.isEmpty)
                    const Text('Sem movimentos.')
                  else
                    ...moves.map((m) {
                      final amount = (m['amount'] ?? 0) as num;
                      return ListTile(
                        dense: true,
                        title: Text('${m['type']} - ${_money(amount)}'),
                        subtitle: Text('Data: ${m['createdAt']}  Obs: ${m['note'] ?? ''}'),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
