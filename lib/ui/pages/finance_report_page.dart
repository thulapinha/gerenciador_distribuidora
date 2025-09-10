// lib/ui/pages/finance_report_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../repositories/sale_repository.dart';

class FinanceReportPage extends StatefulWidget {
  const FinanceReportPage({super.key});
  static const route = '/financeiro';

  @override
  State<FinanceReportPage> createState() => _FinanceReportPageState();
}

class _FinanceReportPageState extends State<FinanceReportPage> {
  final _repo = SalesRepository();

  bool _loading = true;
  List<ParseObject> _sales = [];
  FinanceTotals? _totals;

  // Filtros
  late DateTime _from; // 00:00:00 local
  late DateTime _to;   // 23:59:59 local
  final Set<String> _methods = {}; // vazio = todos
  final _available = const [
    'CASH', 'PIX', 'CARD_CREDIT', 'CARD_DEBIT',
    'CHECK', 'STORE_CREDIT', 'FOOD_VOUCHER', 'MEAL_VOUCHER',
    'GIFT_CARD', 'FUEL_VOUCHER', 'OTHER', 'MERCADO_PAGO'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listSales(
        start: _from,
        end: _to,
        paymentMethods: _methods.isEmpty ? null : _methods.toList(),
      );
      final totals = _repo.computeTotals(list);
      if (!mounted) return;
      setState(() {
        _sales = list;
        _totals = totals;
      });
    } catch (e) {
      if (mounted) _snack('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Período do relatório',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      setState(() {
        _from = start;
        _to = end;
      });
      _load();
    }
  }

  String _money(num v) => 'R\$ ' + v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Relatório Financeiro', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_month),
                label: Text('${_fmtDate(_from)} — ${_fmtDate(_to)}'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white.withOpacity(.18)),
              ),
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    selected: _methods.isEmpty,
                    label: const Text('Todos'),
                    onSelected: (_) { setState(() => _methods.clear()); _load(); },
                  ),
                  for (final m in _available)
                    FilterChip(
                      selected: _methods.contains(m),
                      label: Text(_label(m)),
                      onSelected: (sel) { setState(() { sel ? _methods.add(m) : _methods.remove(m); }); _load(); },
                    ),
                ],
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              ),
            ],
          ),
        ],
      ),
    );

    final body = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _SummaryRow(totals: _totals),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _sales.isEmpty
                    ? const Center(child: Text('Nenhuma venda no período.'))
                    : Column(
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Text('Vendas do período', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _sales.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                        itemBuilder: (_, i) {
                          final s = _sales[i];
                          final created = (s.get<DateTime>('createdAt') ?? DateTime.now()).toLocal();
                          final disc = (s.get<num>('discount') ?? 0).toDouble();
                          final net = (s.get<num>('total') as num?)?.toDouble() ?? _repo.computeTotals([s]).net;
                          final gross = disc + net;
                          final rcv = (s.get<num>('received') ?? net).toDouble();
                          final chg = math.max(0, rcv - net);
                          final pm = (s.get<String>('paymentMethod') ?? 'UNKNOWN').toUpperCase();
                          final oid = s.objectId ?? '-';

                          return SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                _Cell(width: 120, child: Text(_fmtHour(created))),
                                _Cell(width: 140, child: Text('#$oid')),
                                _Cell(flex: 2, child: Text(_label(pm))),
                                _Cell(width: 120, child: Text(_money(gross))),
                                _Cell(width: 120, child: Text(_money(disc))),
                                _Cell(width: 120, child: Text(_money(net), style: const TextStyle(fontWeight: FontWeight.w600))),
                                _Cell(width: 120, child: Text(_money(rcv))),
                                _Cell(width: 120, child: Text(_money(chg))),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(body: Column(children: [header, body]));
  }

  String _label(String m) {
    switch (m) {
      case 'CASH': return 'Dinheiro';
      case 'PIX': return 'PIX';
      case 'CARD_CREDIT': return 'Cartão Crédito';
      case 'CARD_DEBIT': return 'Cartão Débito';
      case 'CHECK': return 'Cheque';
      case 'STORE_CREDIT': return 'Crédito Loja';
      case 'FOOD_VOUCHER': return 'Vale Alimentação';
      case 'MEAL_VOUCHER': return 'Vale Refeição';
      case 'GIFT_CARD': return 'Vale Presente';
      case 'FUEL_VOUCHER': return 'Vale Combustível';
      case 'MERCADO_PAGO': return 'Mercado Pago';
      default: return m;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtHour(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.totals});
  final FinanceTotals? totals;

  String _money(num v) => 'R\$ ' + v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final t = totals;
    return Row(
      children: [
        Expanded(child: _SummaryCard(title: 'Faturado Bruto', value: _money(t?.gross ?? 0))),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Descontos', value: _money(t?.discount ?? 0))),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Faturado Líquido', value: _money(t?.net ?? 0), emphasized: true)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Recebido', value: _money(t?.received ?? 0))),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Troco', value: _money(t?.change ?? 0))),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(title: 'Nº de Vendas', value: '${t?.count ?? 0}')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, this.emphasized = false});
  final String title;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: emphasized ? cs.primary : Theme.of(context).dividerColor, width: emphasized ? 1.4 : 1),
        color: emphasized ? cs.primaryContainer.withOpacity(.15) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({this.flex, this.width, required this.child});
  final int? flex;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: child));
    if (width != null) return SizedBox(width: width, child: inner);
    return Expanded(flex: flex ?? 1, child: inner);
  }
}
