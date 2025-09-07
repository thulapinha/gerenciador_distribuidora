import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class PdvPage extends StatefulWidget {
  const PdvPage({super.key});

  @override
  State<PdvPage> createState() => _PdvPageState();
}

class _CartItem {
  _CartItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.stock,
    required this.sku,
  });

  final String productId;
  final String name;
  final String unit;
  final double unitPrice;
  final double stock;
  final String sku;

  double qty = 0;
  double get total => unitPrice * qty;
}

class _PdvPageState extends State<PdvPage> {
  final _searchCtl = TextEditingController();
  final _refCtl = TextEditingController();
  final _discountCtl = TextEditingController(text: '0');
  final _receivedCtl = TextEditingController(text: '0');

  final _repo = ProductRepository();
  final _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

  List<Map<String, dynamic>> _results = [];
  final Map<String, _CartItem> _cart = {};

  String _paymentMethod = 'DINHEIRO'; // DINHEIRO | CARTAO | PIX
  bool _loading = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    _refCtl.dispose();
    _discountCtl.dispose();
    _receivedCtl.dispose();
    super.dispose();
  }

  double _toDouble(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ??
          double.tryParse(s) ??
          0.0;

  double get _subtotal =>
      _cart.values.fold<double>(0, (p, e) => p + e.total);

  double get _discount => _toDouble(_discountCtl.text);
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  double get _received => _toDouble(_receivedCtl.text);
  double get _change => (_received - _total).clamp(0, double.infinity);

  Future<void> _search() async {
    final t = _searchCtl.text.trim();
    if (t.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await _repo.searchProducts(t, limit: 20);
      _results = list.map((o) {
        final img = o.get<ParseFileBase>('image');
        return {
          'id': o.objectId,
          'name': o.get<String>('name') ?? '',
          'brand': o.get<String>('brand'),
          'sku': o.get<String>('sku') ?? '',
          'unit': o.get<String>('unit') ?? 'UN',
          'price': (o.get<num>('price') ?? 0).toDouble(),
          'stock': (o.get<num>('stock') ?? 0).toDouble(),
          'imageUrl': img?.url,
        };
      }).toList();
    } catch (e) {
      _snack('Erro ao buscar: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _addToCart(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final stock = (p['stock'] as num?)?.toDouble() ?? 0;

    _cart.putIfAbsent(
      id,
          () => _CartItem(
        productId: id,
        name: p['name'] ?? '',
        unit: p['unit'] ?? 'UN',
        unitPrice: (p['price'] as num?)?.toDouble() ?? 0,
        stock: stock,
        sku: p['sku'] ?? '',
      ),
    );

    final item = _cart[id]!;
    if (item.qty + 1 > item.stock) {
      _snack('Sem saldo suficiente em estoque para ${item.name}.');
      return;
    }
    setState(() => item.qty += 1);
  }

  void _dec(String id) {
    final it = _cart[id];
    if (it == null) return;
    setState(() {
      it.qty -= 1;
      if (it.qty <= 0) _cart.remove(id);
    });
  }

  void _inc(String id) {
    final it = _cart[id];
    if (it == null) return;
    if (it.qty + 1 > it.stock) {
      _snack('Sem saldo suficiente em estoque para ${it.name}.');
      return;
    }
    setState(() => it.qty += 1);
  }

  void _remove(String id) => setState(() => _cart.remove(id));

  Future<String?> _askPaymentMethod() async {
    String tmp = _paymentMethod;
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Forma de pagamento'),
        content: StatefulBuilder(builder: (context, setLocal) {
          return DropdownButtonFormField<String>(
            value: tmp,
            items: const [
              DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'CARTAO', child: Text('Cartão')),
              DropdownMenuItem(value: 'PIX', child: Text('Pix')),
            ],
            onChanged: (v) => setLocal(() => tmp = v ?? 'DINHEIRO'),
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('Confirmar')),
        ],
      ),
    );
    return r;
  }

  Future<void> _finalize() async {
    if (_cart.isEmpty) {
      _snack('Carrinho vazio.');
      return;
    }
    final pay = await _askPaymentMethod();
    if (pay == null) return;

    setState(() => _loading = true);
    try {
      final items = _cart.values
          .map((e) => {
        'productId': e.productId,
        'qty': e.qty,
        'unitPrice': e.unitPrice,
      })
          .toList();

      final fn = ParseCloudFunction('finalizeSale');
      final resp = await fn.execute(parameters: {
        'items': items,
        'discount': _discount,
        'paymentMethod': pay,
        'received': _received,
        'number': _refCtl.text.trim().isEmpty ? null : _refCtl.text.trim(),
      });

      if (!resp.success) {
        throw Exception(resp.error?.message ?? 'Falha ao finalizar');
      }

      if (!mounted) return;
      // Limpa carrinho e campos
      setState(() {
        _cart.clear();
        _refCtl.clear();
        _discountCtl.text = '0';
        _receivedCtl.text = '0';
        _paymentMethod = pay;
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Venda concluída'),
          content: Text('Total: ${_fmt.format(_total)}\nTroco: ${_fmt.format(_change)}'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final bottom = _buildBottomBar(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PDV - Caixa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar por nome/sku/código de barras',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _loading ? null : _search, child: const Text('Buscar')),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Resultados — altura fixa para evitar overflow
          SizedBox(
            height: 140,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(child: Text(''))
                : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final p = _results[i];
                return InkWell(
                  onTap: () => _addToCart(p),
                  child: Container(
                    width: 270,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p['imageUrl'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Image.network(
                              p['imageUrl'],
                              height: 28,
                              width: 28,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Text(
                          p['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (p['brand'] != null)
                          Text(
                            '${p['brand']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        const SizedBox(height: 2),
                        Text('SKU: ${p['sku'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        Text('Estoque: ${p['stock']} ${p['unit']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text(_fmt.format((p['price'] as num).toDouble()), style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        const Text('Toque para adicionar ➕', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Lista do carrinho
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Carrinho vazio'))
                : ListView.separated(
              itemCount: _cart.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = _cart.values.elementAt(i);
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('SKU ${item.sku} • ${_fmt.format(item.unitPrice)} • Saldo: ${item.stock.toStringAsFixed(0)} ${item.unit}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _dec(item.productId)),
                      Text(item.qty.toStringAsFixed(1)),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _inc(item.productId)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(item.productId)),
                    ],
                  ),
                );
              },
            ),
          ),

          bottom,
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _refCtl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Número/Referência da venda (opcional)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
                    DropdownMenuItem(value: 'CARTAO', child: Text('Cartão')),
                    DropdownMenuItem(value: 'PIX', child: Text('Pix')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 'DINHEIRO'),
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Pagamento'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Desconto'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _receivedCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Valor recebido'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _finalize,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Finalizar venda'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal: ${_fmt.format(_subtotal)}'),
              Text('Total: ${_fmt.format(_total)}'),
              Text('Troco: ${_fmt.format(_change)}'),
            ],
          ),
        ],
      ),
    );
  }
}
