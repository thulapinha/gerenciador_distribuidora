import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange? _range;
  bool _loading = false;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day)),
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _generatePdf() async {
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha o período.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final q = QueryBuilder(ParseObject('Sale'))
        ..whereGreaterThanOrEqualsTo('createdAt', _range!.start)
        ..whereLessThanOrEqualTo('createdAt', _range!.end.add(const Duration(days: 1)))
        ..orderByAscending('createdAt')
        ..setLimit(1000);
      final r = await q.query();
      if (!r.success) throw Exception(r.error?.message);
      final sales = (r.results ?? []).cast<ParseObject>();

      final doc = pw.Document();
      final rows = <List<String>>[];
      double total = 0;

      for (final s in sales) {
        final dt = (s.createdAt ?? DateTime.now());
        final num t = s.get<num>('total') ?? 0;
        rows.add([DateFormat('dd/MM/yyyy HH:mm').format(dt), (s.get<String>('number') ?? '-'), _fmt.format(t)]);
        total += t.toDouble();
      }

      doc.addPage(
        pw.Page(
          build: (c) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Relatório de Vendas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(_range!.start)} a ${DateFormat('dd/MM/yyyy').format(_range!.end)}'),
              pw.SizedBox(height: 12),
              if (rows.isEmpty) pw.Text('Sem vendas no período.'),
              if (rows.isNotEmpty)
                pw.Table.fromTextArray(headers: ['Data', 'Nº', 'Total'], data: rows),
              pw.SizedBox(height: 12),
              pw.Text('Total no período: ${_fmt.format(total)}'),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (f) async => doc.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null
                      ? 'Escolher período'
                      : 'Período: ${DateFormat('dd/MM/yyyy').format(_range!.start)} a ${DateFormat('dd/MM/yyyy').format(_range!.end)}'),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _generatePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Gerar PDF (Vendas)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Gere o PDF das vendas em um intervalo de datas.'),
          ],
        ),
      ),
    );
  }
}
