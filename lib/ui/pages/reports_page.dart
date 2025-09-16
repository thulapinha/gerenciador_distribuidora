// lib/ui/pages/reports_page.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// PDF / Preview
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum _ReportType { finance, stock, receivable, payable }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _fmtMoney = NumberFormat.simpleCurrency(locale: 'pt_BR');
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );
  _ReportType _type = _ReportType.finance;

  // filtros do financeiro
  final Set<String> _payFilter = <String>{'ALL'};

  // dados
  bool _loading = false;

  // Financeiro
  List<_FinanceRow> _finance = [];
  double _finGross = 0; // bruto
  double _finDisc = 0; // descontos
  double _finNet = 0; // líquido
  double _finReceived = 0; // recebido
  double _finChange = 0; // troco

  // Estoque
  List<_StockRow> _stock = [];
  int _stkActive = 0, _stkInactive = 0, _stkBelowMin = 0, _stkZero = 0;
  int _stkQtyTotal = 0;
  double _stkTotalCost = 0, _stkPotential = 0;

  // Contas
  List<_LedgerRow> _ledger = [];
  double _ledgerTotal = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  // ==============================================================
  // UI helpers
  // ==============================================================
  String _dateLabel(DateTimeRange r) {
    final f = DateFormat('dd/MM/yyyy');
    return '${f.format(r.start)} — ${f.format(r.end)}';
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _range,
      helpText: 'Escolher período',
      builder: (ctx, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (picked != null) {
      setState(() => _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      ));
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      switch (_type) {
        case _ReportType.finance:
          await _loadFinance();
          break;
        case _ReportType.stock:
          await _loadStock();
          break;
        case _ReportType.receivable:
          await _loadLedger('AccountsReceivable');
          break;
        case _ReportType.payable:
          await _loadLedger('AccountsPayable');
          break;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==============================================================
  // DATA: Financeiro
  // ==============================================================
  static const _payNames = <String, String>{
    'CASH': 'Dinheiro',
    'PIX': 'PIX',
    'CARD_CREDIT': 'Cartão Crédito',
    'CARD_DEBIT': 'Cartão Débito',
    'CHECK': 'Cheque',
    'STORE_CREDIT': 'Crédito Loja',
    'FOOD_VOUCHER': 'Vale Alimentação',
    'MEAL_VOUCHER': 'Vale Refeição',
    'GIFT_CARD': 'Vale Presente',
    'FUEL_VOUCHER': 'Vale Combustível',
    'OTHER': 'Outros',
    'MERCADO_PAGO': 'Mercado Pago',
  };

  // métodos base (tudo que NÃO estiver aqui cai no grupo "Outros")
  static const Set<String> _coreMethods = {
    'CASH', 'PIX', 'CARD_CREDIT', 'CARD_DEBIT'
  };

  bool _matchesPayment(String methodUpper) {
    if (_payFilter.contains('ALL')) return true;
    // grupo "Outros" inclui Mercado Pago e qualquer método fora dos core
    final isOther = !_coreMethods.contains(methodUpper);
    if (_payFilter.contains('OTHER') && isOther) return true;
    return _payFilter.contains(methodUpper);
  }

  Future<void> _loadFinance() async {
    _finance = [];
    _finGross = _finDisc = _finNet = _finReceived = _finChange = 0;

    // tenta em Sale e em Sales (compatibilidade)
    final classes = <String>['Sale', 'Sales'];
    ParseResponse? resp;
    List<ParseObject> rows = [];

    for (final cls in classes) {
      final q = QueryBuilder<ParseObject>(ParseObject(cls))
        ..whereGreaterThanOrEqualsTo('createdAt', _range.start)
        ..whereLessThanOrEqualTo('createdAt', _range.end)
        ..orderByDescending('createdAt')
        ..setLimit(1000);
      try {
        final r = await q.query().timeout(const Duration(seconds: 15));
        if (r.success && (r.results?.isNotEmpty ?? false)) {
          resp = r;
          rows = (r.results ?? []).cast<ParseObject>();
          break;
        }
      } catch (_) {}
    }
    if (!(resp?.success ?? false)) {
      setState(() {});
      return;
    }

    for (final o in rows) {
      final id = o.objectId ?? '';
      final dt = o.createdAt ?? DateTime.now();
      final methodUpper = (o.get<String>('paymentMethod') ?? 'OTHER').toUpperCase();

      if (!_matchesPayment(methodUpper)) continue;

      // números (com fallback)
      double gross = (o.get<num>('gross') ?? o.get<num>('subtotal') ?? o.get<num>('total') ?? 0).toDouble();
      final disc = (o.get<num>('discount') ?? 0).toDouble();
      double net = (o.get<num>('net') ?? o.get<num>('total') ?? (gross - disc)).toDouble();
      double received = (o.get<num>('received') ?? net).toDouble();
      double change = (o.get<num>('change') ?? 0).toDouble();
      final items = (o.get<List>('items') ?? const []).length;

      // Normalização para vendas avulsas salvas como total=0 e troco=recebido
      if (net <= 0 && received > 0 && change == received) {
        net = received;
        change = 0;
        if (gross <= 0) gross = net + disc;
      }
      if (gross < net + disc) gross = net + disc; // consistência

      _finance.add(_FinanceRow(
        id: id,
        date: dt,
        method: methodUpper,
        items: items,
        gross: gross,
        discount: disc,
        net: net,
        received: received,
        change: change,
      ));

      _finGross += gross;
      _finDisc += disc;
      _finNet += net;
      _finReceived += received;
      _finChange += change;
    }
    setState(() {});
  }

  // ==============================================================
  // DATA: Estoque
  // ==============================================================
  Future<void> _loadStock() async {
    _stock = [];
    _stkActive = _stkInactive = _stkBelowMin = _stkZero = 0;
    _stkQtyTotal = 0;
    _stkTotalCost = _stkPotential = 0;

    final q = QueryBuilder<ParseObject>(ParseObject('Product'))
      ..orderByAscending('name')
      ..setLimit(1000);
    try {
      final r = await q.query().timeout(const Duration(seconds: 15));
      if (!(r.success)) {
        setState(() {});
        return;
      }
      final rows = (r.results ?? []).cast<ParseObject>();
      for (final p in rows) {
        final active = (p.get<bool>('active') ?? true);
        final name = p.get<String>('name') ?? 'Produto';
        final sku = p.get<String>('sku') ?? p.get<String>('code') ?? '';
        final unit = p.get<String>('unit') ?? 'UN';
        final qty = (p.get<num>('stock') ?? p.get<num>('quantity') ?? 0).toInt();
        final min = (p.get<num>('minStock') ?? 0).toInt();
        final cost = (p.get<num>('cost') ?? 0).toDouble();
        final price = (p.get<num>('price') ?? 0).toDouble();

        if (active) {
          _stkActive++;
        } else {
          _stkInactive++;
        }
        if (qty == 0) _stkZero++;
        if (min > 0 && qty < min) _stkBelowMin++;

        final totalCost = qty * cost;
        final potential = qty * price;

        _stkQtyTotal += qty;
        _stkTotalCost += totalCost;
        _stkPotential += potential;

        _stock.add(_StockRow(
          name: name,
          sku: sku,
          unit: unit,
          qty: qty,
          min: min,
          cost: cost,
          price: price,
          totalCost: totalCost,
          potential: potential,
        ));
      }
      setState(() {});
    } catch (_) {
      setState(() {});
    }
  }

  // ==============================================================
  // DATA: Contas (receber / pagar)
  // ==============================================================
  Future<void> _loadLedger(String className) async {
    _ledger = [];
    _ledgerTotal = 0;

    final q = QueryBuilder<ParseObject>(ParseObject(className))
      ..whereGreaterThanOrEqualsTo('dueDate', _range.start)
      ..whereLessThanOrEqualTo('dueDate', _range.end)
      ..orderByAscending('dueDate')
      ..setLimit(1000);
    try {
      final r = await q.query().timeout(const Duration(seconds: 15));
      if (!r.success) {
        setState(() {});
        return;
      }
      final rows = (r.results ?? []).cast<ParseObject>();
      for (final o in rows) {
        final dt = o.get<DateTime>('dueDate') ?? o.createdAt ?? DateTime.now();
        final desc = o.get<String>('description') ??
            o.get<String>('title') ??
            (className == 'AccountsReceivable' ? 'A Receber' : 'A Pagar');
        final party = o.get<String>('party') ??
            o.get<String>('customerName') ??
            o.get<String>('supplierName') ??
            '';
        final value = (o.get<num>('value') ?? 0).toDouble();
        final status = (o.get<String>('status') ?? 'pending').toLowerCase();

        _ledger.add(_LedgerRow(
          date: dt,
          description: desc,
          party: party,
          value: value,
          status: status,
        ));
        _ledgerTotal += value;
      }
      setState(() {});
    } catch (_) {
      setState(() {});
    }
  }

  // ==============================================================
  // PDF
  // ==============================================================
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    String title;
    switch (_type) {
      case _ReportType.finance:
        title = 'Relatório Financeiro (Vendas)';
        break;
      case _ReportType.stock:
        title = 'Relatório de Estoque';
        break;
      case _ReportType.receivable:
        title = 'Relatório — Contas a Receber';
        break;
      case _ReportType.payable:
        title = 'Relatório — Contas a Pagar';
        break;
    }

    pw.Widget header() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Período: ${_dateLabel(_range)}', style: const pw.TextStyle(fontSize: 10)),
        if (_type == _ReportType.finance && !_payFilter.contains('ALL'))
          pw.Text('Métodos: ${_payFilter.map((e) => _payNames[e] ?? e).join(', ')}', style: const pw.TextStyle(fontSize: 10)),
      ],
    );

    if (_type == _ReportType.finance) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (ctx) => [
            header(),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _kpiPdf('Faturado Bruto', _fmtMoney.format(_finGross)),
              _kpiPdf('Descontos', _fmtMoney.format(_finDisc)),
              _kpiPdf('Faturado Líquido', _fmtMoney.format(_finNet)),
              _kpiPdf('Recebido', _fmtMoney.format(_finReceived)),
              _kpiPdf('Troco', _fmtMoney.format(_finChange)),
              _kpiPdf('Nº Vendas', _finance.length.toString()),
            ]),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Data', 'ID', 'Método', 'Itens', 'Bruto', 'Desc', 'Líquido', 'Recebido', 'Troco'],
              data: _finance.map((r) => [
                DateFormat('dd/MM HH:mm').format(r.date),
                r.id.substring(0, 6).toUpperCase(),
                _payNames[r.method] ?? r.method,
                r.items.toString(),
                _fmtMoney.format(r.gross),
                _fmtMoney.format(r.discount),
                _fmtMoney.format(r.net),
                _fmtMoney.format(r.received),
                _fmtMoney.format(r.change),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              },
            ),
          ],
        ),
      );
    } else if (_type == _ReportType.stock) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (ctx) => [
            header(),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _kpiPdf('Ativos', '$_stkActive'),
              _kpiPdf('Inativos', '$_stkInactive'),
              _kpiPdf('Abaixo do Mínimo', '$_stkBelowMin'),
              _kpiPdf('Zerados', '$_stkZero'),
              _kpiPdf('Qtd Total', '$_stkQtyTotal'),
            ]),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _kpiPdf('Valor em Custo', _fmtMoney.format(_stkTotalCost)),
              _kpiPdf('Potencial (Venda)', _fmtMoney.format(_stkPotential)),
            ]),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Produto', 'SKU', 'Un', 'Qtd', 'Mín', 'Custo', 'Preço', 'Total Custo', 'Potencial'],
              data: _stock.map((s) => [
                s.name,
                s.sku,
                s.unit,
                s.qty.toString(),
                s.min.toString(),
                _fmtMoney.format(s.cost),
                _fmtMoney.format(s.price),
                _fmtMoney.format(s.totalCost),
                _fmtMoney.format(s.potential),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );
    } else {
      // contas a receber / pagar
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (ctx) => [
            header(),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _kpiPdf('Total no período', _fmtMoney.format(_ledgerTotal)),
              _kpiPdf('Lançamentos', _ledger.length.toString()),
            ]),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Vencimento', 'Descrição', 'Parte', 'Status', 'Valor'],
              data: _ledger.map((l) => [
                DateFormat('dd/MM/yyyy').format(l.date),
                l.description,
                l.party,
                l.status,
                _fmtMoney.format(l.value),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _kpiPdf(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(right: 6, bottom: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // WIDGET
  // ==============================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget header = Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          const Text('Relatórios',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today),
            label: Text(_dateLabel(_range)),
            style: FilledButton.styleFrom(foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          _typeChips(),
          if (_type == _ReportType.finance) _methodChips(),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final bytes = await _buildPdf(PdfPageFormat.a4);
              await Printing.sharePdf(bytes: bytes, filename: _pdfFileName());
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Gerar PDF'),
          ),
        ],
      ),
    );

    final body = _loading
        ? const Expanded(
      child: Center(child: CircularProgressIndicator()),
    )
        : Expanded(child: _buildBodyContent());

    return Scaffold(
      body: Column(children: [
        header,
        const SizedBox(height: 8),
        body,
      ]),
    );
  }

  String _pdfFileName() {
    final base = switch (_type) {
      _ReportType.finance => 'relatorio_financeiro',
      _ReportType.stock => 'relatorio_estoque',
      _ReportType.receivable => 'relatorio_receber',
      _ReportType.payable => 'relatorio_pagar',
    };
    return '${base}_${DateFormat('yyyyMMdd').format(_range.start)}_${DateFormat('yyyyMMdd').format(_range.end)}.pdf';
  }


  Widget _typeChips() {
    Widget chip(_ReportType t, String label, IconData icon) => FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: _type == t,
      onSelected: (_) {
        setState(() => _type = t);
        _reload();
      },
    );

    return Wrap(
      spacing: 8,
      children: [
        chip(_ReportType.finance, 'Financeiro (Vendas)', Icons.payments_outlined),
        chip(_ReportType.stock, 'Estoque', Icons.inventory_2_outlined),
        chip(_ReportType.receivable, 'A Receber', Icons.trending_up),
        chip(_ReportType.payable, 'A Pagar', Icons.trending_down),
      ],
    );
  }

  Widget _methodChips() {
    Widget mchip(String code) => FilterChip(
      label: Text(_payNames[code] ?? code),
      selected: _payFilter.contains('ALL') ? code == 'ALL' : _payFilter.contains(code),
      onSelected: (sel) {
        setState(() {
          if (code == 'ALL') {
            _payFilter
              ..clear()
              ..add('ALL');
          } else {
            _payFilter.remove('ALL');
            if (sel) {
              _payFilter.add(code);
            } else {
              _payFilter.remove(code);
              if (_payFilter.isEmpty) _payFilter.add('ALL');
            }
          }
        });
        _reload();
      },
    );

    final order = [
      'ALL',
      'PIX',
      'CASH',
      'CARD_CREDIT',
      'CARD_DEBIT',
      'MERCADO_PAGO',
      'CHECK',
      'STORE_CREDIT',
      'FOOD_VOUCHER',
      'MEAL_VOUCHER',
      'GIFT_CARD',
      'FUEL_VOUCHER',
      'OTHER',
    ];

    return Wrap(
      spacing: 6,
      children: order.map(mchip).toList(),
    );
  }

  Widget _buildBodyContent() {
    switch (_type) {
      case _ReportType.finance:
        return Column(
          children: [
            _financeKpis(),
            const SizedBox(height: 8),
            Expanded(child: _financeTable()),
            const Divider(height: 1),
            SizedBox(
              height: 360,
              child: PdfPreview(
                build: _buildPdf,
                canDebug: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: _pdfFileName(),
              ),
            ),
          ],
        );
      case _ReportType.stock:
        return Column(
          children: [
            _stockKpis(),
            const SizedBox(height: 8),
            Expanded(child: _stockTable()),
            const Divider(height: 1),
            SizedBox(
              height: 360,
              child: PdfPreview(
                build: _buildPdf,
                canChangeOrientation: false,
                canChangePageFormat: false,
                pdfFileName: _pdfFileName(),
              ),
            ),
          ],
        );
      case _ReportType.receivable:
      case _ReportType.payable:
        return Column(
          children: [
            _ledgerKpis(),
            const SizedBox(height: 8),
            Expanded(child: _ledgerTable()),
            const Divider(height: 1),
            SizedBox(
              height: 360,
              child: PdfPreview(
                build: _buildPdf,
                canChangeOrientation: false,
                canChangePageFormat: false,
                pdfFileName: _pdfFileName(),
              ),
            ),
          ],
        );
    }
  }

  // ======= Finance UI =======
  Widget _financeKpis() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _KpiCard(title: 'Faturado Bruto', value: _fmtMoney.format(_finGross)),
          _KpiCard(title: 'Descontos', value: _fmtMoney.format(_finDisc)),
          _KpiCard(title: 'Faturado Líquido', value: _fmtMoney.format(_finNet)),
          _KpiCard(title: 'Recebido', value: _fmtMoney.format(_finReceived)),
          _KpiCard(title: 'Troco', value: _fmtMoney.format(_finChange)),
          _KpiCard(title: 'Nº de Vendas', value: _finance.length.toString()),
        ],
      ),
    );
  }

  Widget _financeTable() {
    if (_finance.isEmpty) {
      return const Center(child: Text('Sem vendas no período.'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Data')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Método')),
              DataColumn(label: Text('Itens')),
              DataColumn(label: Text('Bruto')),
              DataColumn(label: Text('Desc')),
              DataColumn(label: Text('Líquido')),
              DataColumn(label: Text('Recebido')),
              DataColumn(label: Text('Troco')),
            ],
            rows: _finance
                .map((r) => DataRow(cells: [
              DataCell(Text(DateFormat('dd/MM HH:mm').format(r.date))),
              DataCell(Text(r.id.substring(0, 6).toUpperCase())),
              DataCell(Text(_payNames[r.method] ?? r.method)),
              DataCell(Text('${r.items}')),
              DataCell(Text(_fmtMoney.format(r.gross))),
              DataCell(Text(_fmtMoney.format(r.discount))),
              DataCell(Text(_fmtMoney.format(r.net))),
              DataCell(Text(_fmtMoney.format(r.received))),
              DataCell(Text(_fmtMoney.format(r.change))),
            ]))
                .toList(),
          ),
        ),
      ),
    );
  }

  // ======= Stock UI =======
  Widget _stockKpis() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _KpiCard(title: 'Produtos Ativos', value: '$_stkActive'),
          _KpiCard(title: 'Produtos Inativos', value: '$_stkInactive'),
          _KpiCard(title: 'Abaixo do Mínimo', value: '$_stkBelowMin'),
          _KpiCard(title: 'Zerados', value: '$_stkZero'),
          _KpiCard(title: 'Qtd. total', value: '$_stkQtyTotal'),
          _KpiCard(title: 'Valor em Custo', value: _fmtMoney.format(_stkTotalCost)),
          _KpiCard(title: 'Valor Potencial (Venda)', value: _fmtMoney.format(_stkPotential)),
        ],
      ),
    );
  }

  Widget _stockTable() {
    if (_stock.isEmpty) {
      return const Center(child: Text('Sem itens de estoque.'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Produto')),
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Un')),
              DataColumn(label: Text('Qtd')),
              DataColumn(label: Text('Mín')),
              DataColumn(label: Text('Custo')),
              DataColumn(label: Text('Preço')),
              DataColumn(label: Text('Total Custo')),
              DataColumn(label: Text('Potencial')),
            ],
            rows: _stock
                .map((s) => DataRow(cells: [
              DataCell(Text(s.name)),
              DataCell(Text(s.sku)),
              DataCell(Text(s.unit)),
              DataCell(Text('${s.qty}')),
              DataCell(Text('${s.min}')),
              DataCell(Text(_fmtMoney.format(s.cost))),
              DataCell(Text(_fmtMoney.format(s.price))),
              DataCell(Text(_fmtMoney.format(s.totalCost))),
              DataCell(Text(_fmtMoney.format(s.potential))),
            ]))
                .toList(),
          ),
        ),
      ),
    );
  }

  // ======= Ledger UI (A Receber / A Pagar) =======
  Widget _ledgerKpis() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _KpiCard(title: 'Lançamentos', value: _ledger.length.toString()),
          _KpiCard(title: 'Total no período', value: _fmtMoney.format(_ledgerTotal)),
        ],
      ),
    );
  }

  Widget _ledgerTable() {
    if (_ledger.isEmpty) {
      return const Center(child: Text('Nenhum lançamento no período.'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Vencimento')),
              DataColumn(label: Text('Descrição')),
              DataColumn(label: Text('Parte')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Valor')),
            ],
            rows: _ledger
                .map((l) => DataRow(cells: [
              DataCell(Text(DateFormat('dd/MM/yyyy').format(l.date))),
              DataCell(Text(l.description)),
              DataCell(Text(l.party)),
              DataCell(Text(l.status)),
              DataCell(Text(_fmtMoney.format(l.value))),
            ]))
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ====== Small components ======
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
        color: cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(title, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ====== Data models (view) ======
class _FinanceRow {
  _FinanceRow({
    required this.id,
    required this.date,
    required this.method,
    required this.items,
    required this.gross,
    required this.discount,
    required this.net,
    required this.received,
    required this.change,
  });

  final String id;
  final DateTime date;
  final String method;
  final int items;
  final double gross;
  final double discount;
  final double net;
  final double received;
  final double change;
}

class _StockRow {
  _StockRow({
    required this.name,
    required this.sku,
    required this.unit,
    required this.qty,
    required this.min,
    required this.cost,
    required this.price,
    required this.totalCost,
    required this.potential,
  });

  final String name;
  final String sku;
  final String unit;
  final int qty;
  final int min;
  final double cost;
  final double price;
  final double totalCost;
  final double potential;
}

class _LedgerRow {
  _LedgerRow({
    required this.date,
    required this.description,
    required this.party,
    required this.value,
    required this.status,
  });

  final DateTime date;
  final String description;
  final String party;
  final double value;
  final String status;
}
