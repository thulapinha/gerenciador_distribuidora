import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:gerenciador_distribuidora/repositories/product_repository.dart';

class ProductFormPage extends StatefulWidget {
  final String? productId;
  const ProductFormPage({super.key, this.productId});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductRepository();

  final _name = TextEditingController();
  final _sku = TextEditingController();        // usa como CÓDIGO
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'UN');
  final _category = TextEditingController();
  final _ncm = TextEditingController();
  final _brand = TextEditingController();

  final _price = TextEditingController(text: '0');   // venda (auto por custo+margem)
  final _cost = TextEditingController(text: '0');    // custo
  final _margin = TextEditingController(text: '0');  // %

  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _maxStock = TextEditingController(text: '0');

  bool _active = true;
  ParseFileBase? _image;
  String? _objectId;
  bool _saving = false;
  bool _loading = true;
  bool _updating = false;

  late final TabController _tabs;
  bool _autoPrice = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _cost.addListener(_fromCostMarginRecalcPrice);
    _margin.addListener(_fromCostMarginRecalcPrice);
    _price.addListener(_fromCostPriceRecalcMargin);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _unit.dispose();
    _category.dispose();
    _ncm.dispose();
    _brand.dispose();
    _price.dispose();
    _cost.dispose();
    _margin.dispose();
    _stock.dispose();
    _minStock.dispose();
    _maxStock.dispose();
    super.dispose();
  }

  // ----------- PARSER ROBUSTO (BR/US) ------------
  // Aceita: "1,50", "1.50", "1.234,56", "1,234.56", com/sem símbolos.
  double _toD(TextEditingController c) => _parseDecimal(c.text);

  double _parseDecimal(String t) {
    var s = t.trim();
    if (s.isEmpty) return 0.0;

    // remove tudo que não for dígito/separadores/menos
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    if (hasComma && hasDot) {
      // Convenção BR: '.' milhares, ',' decimais  -> remove '.' e troca ',' por '.'
      // Ex.: "1.234,56" -> "1234.56"
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma && !hasDot) {
      // Somente vírgula -> usa como decimal
      s = s.replaceAll(',', '.');
    } else {
      // Só ponto ou sem separador -> já ok
    }

    return double.tryParse(s) ?? 0.0;
  }

  void _fromCostMarginRecalcPrice() {
    if (_updating || !_autoPrice) return;
    _updating = true;
    final cost = _toD(_cost);
    final margin = _toD(_margin);
    final price = cost * (1 + margin / 100);
    _price.text = price.isFinite ? price.toStringAsFixed(2) : '0';
    _updating = false;
    setState(() {});
  }

  void _fromCostPriceRecalcMargin() {
    if (_updating) return;
    _updating = true;
    final cost = _toD(_cost);
    final price = _toD(_price);
    final margin = cost <= 0 ? 0 : ((price / cost) - 1) * 100;
    _margin.text = margin.isFinite ? margin.toStringAsFixed(2) : '0';
    _updating = false;
    setState(() {});
  }

  Future<void> _load() async {
    if (widget.productId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final o = await _repo.getById(widget.productId!);
      if (o != null) {
        _objectId = o.objectId;
        _name.text = o.get<String>('name') ?? '';
        _sku.text = o.get<String>('sku') ?? '';
        _barcode.text = o.get<String>('barcode') ?? '';
        _unit.text = o.get<String>('unit') ?? 'UN';
        _category.text = o.get<String>('category') ?? '';
        _ncm.text = o.get<String>('ncm') ?? '';
        _brand.text = o.get<String>('brand') ?? '';
        _price.text = ((o.get<num>('price') ?? 0).toDouble()).toStringAsFixed(2);
        _cost.text = ((o.get<num>('cost') ?? 0).toDouble()).toStringAsFixed(2);
        _margin.text = ((o.get<num>('margin') ?? 0).toDouble()).toStringAsFixed(2);
        _stock.text = ((o.get<num>('stock') ?? 0).toDouble()).toStringAsFixed(0);
        _minStock.text = ((o.get<num>('minStock') ?? 0).toDouble()).toStringAsFixed(0);
        _maxStock.text = ((o.get<num>('maxStock') ?? 0).toDouble()).toStringAsFixed(0);
        _active = o.get<bool>('active') ?? true;
      }
    } catch (e) {
      _snack('Erro: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    try {
      if (kIsWeb) {
        _image = ParseWebFile(f.bytes!, name: f.name);
      } else {
        _image = ParseFile(File(f.path!), name: f.name);
      }
      _snack('Imagem selecionada: ${f.name}');
      setState(() {});
    } catch (e) {
      _snack('Falha ao carregar imagem: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // valida duplicidade
    if (await _repo.existsSku(_sku.text.trim(), exceptId: _objectId)) {
      _snack('Já existe um produto com este CÓDIGO (SKU).');
      return;
    }
    final bc = _barcode.text.trim();
    if (bc.isNotEmpty && await _repo.existsBarcode(bc, exceptId: _objectId)) {
      _snack('Já existe um produto com este CÓDIGO DE BARRAS.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.upsertProduct(
        objectId: _objectId,
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        barcode: bc.isEmpty ? null : bc,
        unit: _unit.text.trim().isEmpty ? 'UN' : _unit.text.trim(),
        price: _toD(_price),
        cost: _toD(_cost),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        ncm: _ncm.text.trim().isEmpty ? null : _ncm.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        margin: _toD(_margin),
        stock: _toD(_stock),
        minStock: _toD(_minStock),
        maxStock: _toD(_maxStock),
        imageFile: _image,
        active: _active,
      );

      if (!mounted) return;
      _snack('Produto salvo.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Erro ao salvar: $e');
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ----------------------------------------------------------------------------
  // UI (layout estilo SIGE)
  // ----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(
        _objectId == null ? 'Adicionar Produto' : 'Editar Produto',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );

    final basicIdentity = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(labelText: 'Código *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: 'Simples',
                    items: const [
                      DropdownMenuItem(value: 'Simples', child: Text('Simples')),
                      DropdownMenuItem(value: 'Composto', child: Text('Composto')),
                    ],
                    onChanged: (_) {},
                    decoration: const InputDecoration(labelText: 'Tipo do Produto *', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    decoration: const InputDecoration(labelText: 'Código de Barras', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unidade', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _brand,
                    decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category.text.isEmpty ? null : _category.text,
                    items: const [
                      DropdownMenuItem(value: 'Bebidas', child: Text('Bebidas')),
                      DropdownMenuItem(value: 'Alimentos', child: Text('Alimentos')),
                      DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                    ],
                    onChanged: (v) => setState(() => _category.text = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ncm,
                    decoration: const InputDecoration(labelText: 'NCM', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cadastro Inativo'),
                    const SizedBox(width: 8),
                    Switch(value: !_active, onChanged: (v) => setState(() => _active = !v)),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );

    final tabs = Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Básico'),
            Tab(text: 'Fornecedores'),
            Tab(text: 'Fiscal'),
            Tab(text: 'Campos Personalizados'),
            Tab(text: 'Foods'),
          ],
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabs,
            children: [
              _basicPricingTab(),
              _placeholder('Fornecedores'),
              _placeholder('Fiscal'),
              _placeholder('Campos Personalizados'),
              _placeholder('Foods'),
            ],
          ),
        ),
      ],
    );

    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('Imagem')),
          Row(
            children: [
              TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('CANCELAR')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: const Text('SALVAR'),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          header,
          basicIdentity,
          tabs,
          const Divider(height: 1),
          actions,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _basicPricingTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custos e Precificação', style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: 'R\$ ', labelText: 'Preço de Custo', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _margin,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: '%', labelText: 'MVA/Margem %', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: 'R\$ ', labelText: 'Preço de Venda', border: OutlineInputBorder()),
                  onChanged: (_) => _autoPrice = false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(value: _autoPrice, onChanged: (v) => setState(() => _autoPrice = v)),
              const Text('Calcular preço automaticamente por Custo + MVA/Margem'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Estoque Atual'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _minStock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Estoque Mín.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maxStock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Estoque Máx.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title) {
    return Center(child: Text('$title — em breve'));
  }
}
