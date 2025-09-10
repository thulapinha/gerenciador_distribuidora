// lib/ui/pages/stock_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class StockDashboardPage extends StatefulWidget {
  const StockDashboardPage({super.key});
  static const route = '/estoque_dashboard';

  @override
  State<StockDashboardPage> createState() => _StockDashboardPageState();
}

class _StockDashboardPageState extends State<StockDashboardPage> {
  bool _loading = true;
  List<ParseObject> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = QueryBuilder<ParseObject>(ParseObject('Product'))
        ..setLimit(1000)
        ..orderByAscending('name');
      final r = await q.query();
      if (!r.success) throw Exception(r.error?.message);
      if (!mounted) return;
      setState(() => _all = (r.results ?? []).cast<ParseObject>());
    } catch (e) {
      if (mounted) _snack('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // KPIs
  int get _activeCount => _all.where((e) => (e.get<bool>('active') ?? true)).length;
  int get _inactiveCount => _all.where((e) => !(e.get<bool>('active') ?? true)).length;
  int get _zeroCount => _all.where((e) => ((e.get<num>('stock') ?? 0).toDouble() <= 0)).length;
  int get _belowMinCount => _all.where((e) {
    final st = (e.get<num>('stock') ?? 0).toDouble();
    final min = (e.get<num>('minStock') ?? 0).toDouble();
    return st <= min;
  }).length;
  double get _qtyTotal => _all.fold(0.0, (p, e) => p + ((e.get<num>('stock') ?? 0).toDouble()));
  double get _valueCost => _all.fold(0.0, (p, e) {
    final st = (e.get<num>('stock') ?? 0).toDouble();
    final c = (e.get<num>('cost') ?? 0).toDouble();
    return p + st * c;
  });
  double get _valueRetail => _all.fold(0.0, (p, e) {
    final st = (e.get<num>('stock') ?? 0).toDouble();
    final pr = (e.get<num>('price') ?? 0).toDouble();
    return p + st * pr;
  });

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
      child: Row(
        children: [
          const Text('Dashboard de Estoque', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white.withOpacity(.18)),
          ),
        ],
      ),
    );

    final kpis = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _KpiCard(title: 'Produtos Ativos', value: '$_activeCount'),
          _KpiCard(title: 'Produtos Inativos', value: '$_inactiveCount'),
          _KpiCard(title: 'Abaixo do Mínimo', value: '$_belowMinCount', emphasized: true),
          _KpiCard(title: 'Zerados', value: '$_zeroCount'),
          _KpiCard(title: 'Qtd. Total em Estoque', value: _qtyTotal.truncateToDouble() == _qtyTotal ? _qtyTotal.toStringAsFixed(0) : _qtyTotal.toStringAsFixed(1)),
          _KpiCard(title: 'Valor em Custo', value: _money(_valueCost)),
          _KpiCard(title: 'Valor Potencial (Venda)', value: _money(_valueRetail)),
        ],
      ),
    );

    final lists = Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(child: _Panel(
              title: 'Atenção: Abaixo do Mínimo',
              child: _loading
                  ? const _CenterProgress()
                  : _ListProducts(
                data: _all.where((e) {
                  final st = (e.get<num>('stock') ?? 0).toDouble();
                  final min = (e.get<num>('minStock') ?? 0).toDouble();
                  return st <= min;
                }).toList()
                  ..sort((a, b) =>
                      ((a.get<num>('stock') ?? 0).toDouble()).compareTo((b.get<num>('stock') ?? 0).toDouble())),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: _Panel(
              title: 'Maior Valor Parado (Custo)',
              child: _loading
                  ? const _CenterProgress()
                  : _ListProducts(
                data: _all.toList()
                  ..sort((a, b) {
                    final va = ((a.get<num>('stock') ?? 0).toDouble()) * ((a.get<num>('cost') ?? 0).toDouble());
                    final vb = ((b.get<num>('stock') ?? 0).toDouble()) * ((b.get<num>('cost') ?? 0).toDouble());
                    return vb.compareTo(va);
                  }),
                limit: 20,
                subtitleBuilder: (o) {
                  final st = (o.get<num>('stock') ?? 0).toDouble();
                  final c = (o.get<num>('cost') ?? 0).toDouble();
                  return 'QTD ${_fmtQty(st)}  •  Custo ${_money(c)}  •  Total ${_money(st * c)}';
                },
              ),
            )),
          ],
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          if (_loading && _all.isEmpty) const Expanded(child: _CenterProgress()) else ...[
            kpis,
            lists,
          ]
        ],
      ),
    );
  }

  String _fmtQty(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, this.emphasized = false});
  final String title;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: emphasized ? cs.primary : Theme.of(context).dividerColor, width: emphasized ? 1.4 : 1),
          color: emphasized ? cs.primaryContainer.withOpacity(.15) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ListProducts extends StatelessWidget {
  const _ListProducts({required this.data, this.limit, this.subtitleBuilder});
  final List<ParseObject> data;
  final int? limit;
  final String Function(ParseObject o)? subtitleBuilder;

  String _money(num v) => 'R\$ ' + v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final list = (limit != null && data.length > limit!) ? data.take(limit!).toList() : data;
    if (list.isEmpty) return const Center(child: Text('Sem itens.'));
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
      itemBuilder: (_, i) {
        final o = list[i];
        final name = o.get<String>('name') ?? '-';
        final st = (o.get<num>('stock') ?? 0).toDouble();
        final min = (o.get<num>('minStock') ?? 0).toDouble();
        final unit = o.get<String>('unit') ?? 'UN';
        final price = (o.get<num>('price') ?? 0).toDouble();

        return ListTile(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitleBuilder?.call(o) ?? 'QTD ${_fmtQty(st)} ($unit) • Mín ${_fmtQty(min)} • Preço ${_money(price)}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        );
      },
    );
  }

  String _fmtQty(double v) => v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _CenterProgress extends StatelessWidget {
  const _CenterProgress();
  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4)));
  }
}
