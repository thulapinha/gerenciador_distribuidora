import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/session.dart';
import '../../core/rbac.dart';
import '../../core/csv_export.dart';

class FinanceReportPage extends StatefulWidget {
  const FinanceReportPage({super.key});

  @override
  State<FinanceReportPage> createState() => _FinanceReportPageState();
}

class _FinanceReportPageState extends State<FinanceReportPage> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 7));
  DateTime _end = DateTime.now();
  String _paymentFilter = 'ALL';
  bool _loading = false;
  List<SaleRow> _rows = [];

  // Agregados
  int get count => _rows.length;
  double get subtotalSum => _rows.fold(0, (p, e) => p + e.subtotal);
  double get discountSum => _rows.fold(0, (p, e) => p + e.discount);
  double get totalSum => _rows.fold(0, (p, e) => p + e.total);
  double get receivedSum => _rows.fold(0, (p, e) => p + e.received);
  double get changeSum => _rows.fold(0, (p, e) => p + e.change);

  Map<String, double> get byPayment => _rows.fold(<String, double>{}, (map, e) {
    map[e.paymentMethod] = (map[e.paymentMethod] ?? 0) + e.total;
    return map;
  });

  final _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _start,
    );
    if (d != null) {
      setState(() => _start = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _end,
    );
    if (d != null) {
      // fim do dia
      setState(() => _end = DateTime(d.year, d.month, d.day, 23, 59, 59));
    }
  }

  Future<void> _fetch() async {
    if (!Session.i.can(Caps.financeRead)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem permissão: finance.read')),
      );
      return;
    }
    setState(() => _loading = true);

    try {
      final q = QueryBuilder<ParseObject>(ParseObject('Sale'))
        ..whereGreaterThanOrEqualsTo('createdAt', _start)
        ..whereLessThanOrEqualTo('createdAt', _end)
        ..whereEqualTo('status', 'DONE')
        ..orderByAscending('createdAt')
        ..setLimit(1000);

      if (_paymentFilter != 'ALL') {
        q.whereEqualTo('paymentMethod', _paymentFilter);
      }

      final res = await q.query();
      if (res.success && res.results != null) {
        final list = res.results!.cast<ParseObject>();
        _rows = list.map((o) => SaleRow.fromParse(o)).toList();
      } else {
        _rows = [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final rows = <List<dynamic>>[];
      rows.add([
        'Data',
        'Número',
        'Cliente CPF',
        'Subtotal',
        'Desconto',
        'Total',
        'Recebido',
        'Troco',
        'Pagamento',
        'CriadoPor',
        'PapelCriador'
      ]);

      for (final r in _rows) {
        rows.add([
          _dateFmt.format(r.createdAt),
          r.number ?? '',
          r.customerCpf ?? '',
          r.subtotal,
          r.discount,
          r.total,
          r.received,
          r.change,
          r.paymentMethod,
          r.createdBy ?? '',
          r.createdByRole ?? '',
        ]);
      }

      final file = await saveCsv(
        'finance_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
        rows,
        dir,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV salvo em: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao exportar CSV: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.i.can(Caps.financeRead)) {
      return const Center(child: Text('Acesso negado'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Filters(
            start: _start,
            end: _end,
            paymentFilter: _paymentFilter,
            onPickStart: _pickStart,
            onPickEnd: _pickEnd,
            onPaymentChange: (v) => setState(() => _paymentFilter = v),
            onSearch: _fetch,
            onExport: _exportCsv,
            busy: _loading,
          ),
          const SizedBox(height: 12),
          _TotalsBar(
            count: count,
            subtotal: subtotalSum,
            discount: discountSum,
            total: totalSum,
            received: receivedSum,
            change: changeSum,
            byPayment: byPayment,
            currency: _fmt,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('Nenhuma venda encontrada no período.'))
                  : _Table(
                rows: _rows,
                currency: _fmt,
                dateFmt: _dateFmt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final DateTime start, end;
  final String paymentFilter;
  final VoidCallback onPickStart, onPickEnd, onSearch, onExport;
  final ValueChanged<String> onPaymentChange;
  final bool busy;

  const _Filters({
    required this.start,
    required this.end,
    required this.paymentFilter,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPaymentChange,
    required this.onSearch,
    required this.onExport,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Row(
      children: [
        Flexible(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Início'),
            child: InkWell(
              onTap: busy ? null : onPickStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(df.format(start)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Fim'),
            child: InkWell(
              onTap: busy ? null : onPickEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(df.format(end)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: DropdownButtonFormField<String>(
            value: paymentFilter,
            decoration: const InputDecoration(labelText: 'Pagamento'),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('Todos')),
              DropdownMenuItem(value: 'CASH', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'CARD', child: Text('Cartão')),
              DropdownMenuItem(value: 'PIX', child: Text('PIX')),
              DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
            ],
            onChanged: (v) => onPaymentChange(v ?? 'ALL'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: busy ? null : onSearch,
          icon: const Icon(Icons.search),
          label: const Text('Buscar'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onExport,
          icon: const Icon(Icons.download),
          label: const Text('Exportar CSV'),
        ),
      ],
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final int count;
  final double subtotal, discount, total, received, change;
  final Map<String, double> byPayment;
  final NumberFormat currency;

  const _TotalsBar({
    required this.count,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.received,
    required this.change,
    required this.byPayment,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value) => Chip(
      label: Row(children: [Text(label), const SizedBox(width: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Vendas', '$count'),
        chip('Subtotal', currency.format(subtotal)),
        chip('Descontos', currency.format(discount)),
        chip('Total', currency.format(total)),
        chip('Recebido', currency.format(received)),
        chip('Troco', currency.format(change)),
        for (final e in byPayment.entries) chip('Pag. ${e.key}', currency.format(e.value)),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  final List<SaleRow> rows;
  final NumberFormat currency;
  final DateFormat dateFmt;

  const _Table({
    required this.rows,
    required this.currency,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Número')),
            DataColumn(label: Text('Cliente CPF')),
            DataColumn(label: Text('Subtotal')),
            DataColumn(label: Text('Desconto')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Recebido')),
            DataColumn(label: Text('Troco')),
            DataColumn(label: Text('Pagamento')),
            DataColumn(label: Text('Criado por')),
            DataColumn(label: Text('Papel')),
          ],
          rows: rows
              .map(
                (r) => DataRow(
              cells: [
                DataCell(Text(dateFmt.format(r.createdAt))),
                DataCell(Text(r.number ?? '')),
                DataCell(Text(r.customerCpf ?? '')),
                DataCell(Text(currency.format(r.subtotal))),
                DataCell(Text(currency.format(r.discount))),
                DataCell(Text(currency.format(r.total))),
                DataCell(Text(currency.format(r.received))),
                DataCell(Text(currency.format(r.change))),
                DataCell(Text(r.paymentMethod)),
                DataCell(Text(r.createdBy ?? '')),
                DataCell(Text(r.createdByRole ?? '')),
              ],
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

class SaleRow {
  final DateTime createdAt;
  final String? number;
  final String? customerCpf;
  final double subtotal;
  final double discount;
  final double total;
  final double received;
  final double change;
  final String paymentMethod;
  final String? createdBy;
  final String? createdByRole;

  SaleRow({
    required this.createdAt,
    required this.number,
    required this.customerCpf,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.received,
    required this.change,
    required this.paymentMethod,
    required this.createdBy,
    required this.createdByRole,
  });

  factory SaleRow.fromParse(ParseObject o) {
    double nz(num? v) => (v == null) ? 0.0 : v.toDouble();
    return SaleRow(
      createdAt: o.createdAt ?? DateTime.now(),
      number: o.get<String>('number'),
      customerCpf: o.get<String>('customerCpf'),
      subtotal: nz(o.get<num>('subtotal')),
      discount: nz(o.get<num>('discount')),
      total: nz(o.get<num>('total')),
      received: nz(o.get<num>('received')),
      change: nz(o.get<num>('change')),
      paymentMethod: (o.get<String>('paymentMethod') ?? 'UNKNOWN').toUpperCase(),
      createdBy: (o.get<ParseObject>('createdBy'))?.objectId,
      createdByRole: o.get<String>('createdByRole'),
    );
  }
}
