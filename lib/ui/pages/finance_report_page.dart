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

  // Agregados (usando valores normalizados)
  int get count => _rows.length;
  double get subtotalSum => _rows.fold(0, (p, e) => p + e.subtotal);
  double get discountSum => _rows.fold(0, (p, e) => p + e.discount);
  double get totalSum => _rows.fold(0, (p, e) => p + e.total);      // normalizado
  double get receivedSum => _rows.fold(0, (p, e) => p + e.received);
  double get changeSum => _rows.fold(0, (p, e) => p + e.change);    // normalizado

  Map<String, double> get byPayment =>
      _rows.fold(<String, double>{}, (map, e) {
        map[e.paymentMethod] = (map[e.paymentMethod] ?? 0) + e.total; // total normalizado por método
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
      setState(() => _end = DateTime(d.year, d.month, d.day, 23, 59, 59));
    }
  }

  bool _matchesFilter(String method) {
    final m = (method).toUpperCase();
    switch (_paymentFilter) {
      case 'ALL':
        return true;
      case 'CASH':
        return m == 'CASH';
      case 'CARD':
        return m == 'CARD_CREDIT' || m == 'CARD_DEBIT';
      case 'PIX':
        return m == 'PIX';
      case 'OTHER':
      // tudo que não é CASH / CARD_* / PIX entra aqui (inclui MERCADO_PAGO)
        return !(m == 'CASH' || m == 'PIX' || m == 'CARD_CREDIT' || m == 'CARD_DEBIT');
      default:
        return true;
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

      // ATENÇÃO: filtramos no CLIENTE para permitir mapeamentos (CARD = CREDIT/DEBIT, OTHER inclui MERCADO_PAGO etc.)
      final res = await q.query();
      if (res.success && res.results != null) {
        final list = res.results!.cast<ParseObject>();
        final all = list.map((o) => SaleRow.fromParse(o)).toList();
        _rows = all.where((r) => _matchesFilter(r.paymentMethod)).toList();
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
        'Data','Número','Cliente CPF','Subtotal','Desconto','Total','Recebido','Troco','Pagamento','CriadoPor','PapelCriador'
      ]);

      for (final r in _rows) {
        rows.add([
          _dateFmt.format(r.createdAt),
          r.number ?? '',
          r.customerCpf ?? '',
          r.subtotal,
          r.discount,
          r.total,     // já normalizado
          r.received,
          r.change,    // já normalizado
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
                  : _Table(rows: _rows, currency: _fmt, dateFmt: _dateFmt),
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
                DataCell(Text(currency.format(r.total))),     // normalizado
                DataCell(Text(currency.format(r.received))),
                DataCell(Text(currency.format(r.change))),    // normalizado
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
  final double total;    // já normalizado
  final double received;
  final double change;   // já normalizado
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

    final createdAt = o.createdAt ?? DateTime.now();
    final number = o.get<String>('number');
    final customerCpf = o.get<String>('customerCpf');
    final payment = (o.get<String>('paymentMethod') ?? 'UNKNOWN').toUpperCase();

    // valores do servidor
    final rawSubtotal = nz(o.get<num>('subtotal'));
    final rawDiscount = nz(o.get<num>('discount'));
    var rawTotal = nz(o.get<num>('total'));
    var rawReceived = nz(o.get<num>('received'));
    var rawChange = nz(o.get<num>('change'));

    // Normalização para vendas avulsas salvas como total=0 e troco=recebido
    if (rawTotal <= 0 && rawReceived > 0 && rawChange == rawReceived) {
      rawTotal = rawReceived;
      rawChange = 0;
    }

    return SaleRow(
      createdAt: createdAt,
      number: number,
      customerCpf: customerCpf,
      subtotal: rawSubtotal,
      discount: rawDiscount,
      total: rawTotal,
      received: rawReceived,
      change: rawChange,
      paymentMethod: payment,
      createdBy: (o.get<ParseObject>('createdBy'))?.objectId,
      createdByRole: o.get<String>('createdByRole'),
    );
  }
}
