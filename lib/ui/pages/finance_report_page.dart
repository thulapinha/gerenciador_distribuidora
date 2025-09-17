// lib/ui/pages/finance_report_page.dart
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

  // Custo total (COGS) e agregação diária
  double _costSum = 0.0;
  Map<DateTime, _DailyAgg> _daily = {};

  // Agregados (valores normalizados)
  int get count => _rows.length;
  double get subtotalSum => _rows.fold(0, (p, e) => p + e.subtotal);
  double get discountSum => _rows.fold(0, (p, e) => p + e.discount);
  double get totalSum => _rows.fold(0, (p, e) => p + e.total); // receita líquida
  double get receivedSum => _rows.fold(0, (p, e) => p + e.received);
  double get changeSum => _rows.fold(0, (p, e) => p + e.change);
  double get profitSum => (totalSum - _costSum);

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
      // 1) Vendas
      final q = QueryBuilder<ParseObject>(ParseObject('Sale'))
        ..whereGreaterThanOrEqualsTo('createdAt', _start)
        ..whereLessThanOrEqualTo('createdAt', _end)
        ..whereEqualTo('status', 'DONE')
        ..orderByAscending('createdAt')
        ..setLimit(1000);

      final res = await q.query();
      if (res.success && res.results != null) {
        final list = res.results!.cast<ParseObject>();
        final all = list.map((o) => SaleRow.fromParse(o)).toList();
        _rows = all.where((r) => _matchesFilter(r.paymentMethod)).toList();
      } else {
        _rows = [];
      }

      // 2) Custo total e resumo diário
      await _computeCostsAndDaily();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _computeCostsAndDaily() async {
    _costSum = 0.0;
    _daily = {};

    if (_rows.isEmpty) return;

    // IDs das vendas filtradas
    final salePointers = _rows
        .map((r) => ParseObject('Sale')..objectId = r.objectId)
        .toList();

    // receita diária
    for (final r in _rows) {
      final k = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      final d = _daily.putIfAbsent(k, () => _DailyAgg());
      d.revenue += r.total;
    }

    // itens com product (para custo) + sale (para data)
    final qi = QueryBuilder<ParseObject>(ParseObject('SaleItem'))
      ..whereContainedIn('sale', salePointers)
      ..includeObject(['product', 'sale'])
      ..setLimit(10000);

    final ir = await qi.query();
    if (!ir.success || ir.results == null) return;

    for (final obj in ir.results!.cast<ParseObject>()) {
      final qty = (obj.get<num>('qty') ?? 0).toDouble(); // em UN base
      final product = obj.get<ParseObject>('product');
      final sale = obj.get<ParseObject>('sale');

      final unitCost = (product?.get<num>('cost') ?? 0).toDouble();
      final itemCost = unitCost * qty;
      _costSum += itemCost;

      final dt = sale?.createdAt ?? DateTime.now();
      final key = DateTime(dt.year, dt.month, dt.day);
      final d = _daily.putIfAbsent(key, () => _DailyAgg());
      d.cost += itemCost;
    }

    for (final d in _daily.values) {
      d.profit = d.revenue - d.cost;
    }
  }

  Future<void> _exportCsv() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final rows = <List<dynamic>>[];
      rows.add([
        'Data','Número','Cliente CPF','Subtotal','Desconto','Total',
        'Recebido','Troco','Pagamento','CriadoPor','PapelCriador'
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

      rows.add([]);
      rows.add(['RESUMO']);
      rows.add(['Custo (COGS)', _costSum]);
      rows.add(['Lucro (Total - Custo)', profitSum]);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.i.can(Caps.financeRead)) {
      return const Center(child: Text('Acesso negado'));
    }

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _FiltersCard(
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
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _KpiWrap(
                cards: [
                  KpiData('Vendas', '$count', Icons.receipt_long, color: _Palette.slate),
                  KpiData('Subtotal', _fmt.format(subtotalSum), Icons.summarize, color: _Palette.indigo),
                  KpiData('Descontos', _fmt.format(discountSum), Icons.percent, color: _Palette.red),
                  KpiData('Total', _fmt.format(totalSum), Icons.attach_money, color: _Palette.teal),
                  KpiData('Recebido', _fmt.format(receivedSum), Icons.payments, color: _Palette.blue),
                  KpiData('Troco', _fmt.format(changeSum), Icons.change_circle, color: _Palette.gray),
                  KpiData('Custo (COGS)', _fmt.format(_costSum), Icons.inventory_2, color: _Palette.amber),
                  KpiData('Lucro', _fmt.format(profitSum), Icons.trending_up, color: _Palette.green),
                  for (final e in byPayment.entries)
                    KpiData('Pag. ${e.key}', _fmt.format(e.value), Icons.credit_score,
                        color: _colorForPayment(e.key)),
                ],
              ),
            ),
          ),
          if (_daily.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _DailyCard(
                  data: _daily,
                  currency: _fmt,
                  dateFmt: DateFormat('dd/MM'),
                ),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma venda encontrada no período.'),
                  ),
                )
                    : LayoutBuilder(
                  builder: (ctx, c) => SizedBox.expand(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: _Table(
                          rows: _rows,
                          currency: _fmt,
                          dateFmt: _dateFmt,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForPayment(String key) {
    final k = key.toUpperCase();
    if (k == 'CASH') return _Palette.green;
    if (k == 'PIX') return _Palette.violet;
    if (k == 'CARD_CREDIT') return _Palette.indigo;
    if (k == 'CARD_DEBIT') return _Palette.blue;
    if (k == 'MERCADO_PAGO') return _Palette.cyan;
    return _Palette.slate;
  }
}

// ===================== Paleta de cores =======================================

class _Palette {
  static const indigo = Color(0xFF4F46E5);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);
  static const teal = Color(0xFF14B8A6);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const violet = Color(0xFF7C3AED);
  static const slate = Color(0xFF475569);
  static const gray = Color(0xFF64748B);
}

// ===================== UI Components ========================================

class _FiltersCard extends StatelessWidget {
  final DateTime start, end;
  final String paymentFilter;
  final VoidCallback onPickStart, onPickEnd, onSearch, onExport;
  final ValueChanged<String> onPaymentChange;
  final bool busy;

  const _FiltersCard({
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DateField(
              label: 'Início',
              value: df.format(start),
              onTap: busy ? null : onPickStart,
            ),
            _DateField(
              label: 'Fim',
              value: df.format(end),
              onTap: busy ? null : onPickEnd,
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: paymentFilter,
                decoration: const InputDecoration(
                  labelText: 'Pagamento',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                  DropdownMenuItem(value: 'CASH', child: Text('Dinheiro')),
                  DropdownMenuItem(value: 'CARD', child: Text('Cartão')),
                  DropdownMenuItem(value: 'PIX', child: Text('PIX')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Outros')),
                ],
                onChanged: busy ? null : (v) => onPaymentChange(v ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: busy ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
            ),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('Exportar CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DateField({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  KpiData(this.title, this.value, this.icon, {required this.color});
}

class _KpiWrap extends StatelessWidget {
  final List<KpiData> cards;
  const _KpiWrap({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((k) => _KpiCard(data: k)).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.color;
    return SizedBox(
      width: 250,
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.withOpacity(0.25)),
        ),
        color: c.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.withOpacity(0.15),
                child: Icon(data.icon, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(fontSize: 12, color: c.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.darken(0.15),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}

class _DailyCard extends StatelessWidget {
  final Map<DateTime, _DailyAgg> data;
  final NumberFormat currency;
  final DateFormat dateFmt;

  const _DailyCard({
    required this.data,
    required this.currency,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final days = data.keys.toList()..sort();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo Diário',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStatePropertyAll(
                  Colors.black12.withOpacity(0.06),
                ),
                columns: const [
                  DataColumn(label: Text('Dia')),
                  DataColumn(label: Text('Receita')),
                  DataColumn(label: Text('Custo')),
                  DataColumn(label: Text('Lucro')),
                ],
                rows: days.map((d) {
                  final agg = data[d]!;
                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(d))),
                    DataCell(Text(currency.format(agg.revenue))),
                    DataCell(Text(currency.format(agg.cost))),
                    DataCell(Text(
                      currency.format(agg.profit),
                      style: TextStyle(
                        color: agg.profit >= 0 ? _Palette.green : _Palette.red,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
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
    return DataTable(
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
            (r) => DataRow(cells: [
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
        ]),
      )
          .toList(),
    );
  }
}

// ===================== Models / helpers =====================================

class SaleRow {
  final String objectId;
  final DateTime createdAt;
  final String? number;
  final String? customerCpf;
  final double subtotal;
  final double discount;
  final double total; // já normalizado
  final double received;
  final double change; // já normalizado
  final String paymentMethod;
  final String? createdBy;
  final String? createdByRole;

  SaleRow({
    required this.objectId,
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

    final rawSubtotal = nz(o.get<num>('subtotal'));
    final rawDiscount = nz(o.get<num>('discount'));
    var rawTotal = nz(o.get<num>('total'));
    var rawReceived = nz(o.get<num>('received'));
    var rawChange = nz(o.get<num>('change'));

    if (rawTotal <= 0 && rawReceived > 0 && rawChange == rawReceived) {
      rawTotal = rawReceived;
      rawChange = 0;
    }

    return SaleRow(
      objectId: o.objectId!,
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

class _DailyAgg {
  double revenue = 0.0;
  double cost = 0.0;
  double profit = 0.0;
}
