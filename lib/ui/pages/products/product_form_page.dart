// lib/ui/pages/products/product_form_page.dart
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
  final _sku = TextEditingController();
  final _barcode = TextEditingController();

  // UN/CX/KG
  String _unitKind = 'UN'; // Dropdown principal
  final _unit = TextEditingController(text: 'UN'); // compatibilidade com backend

  final _category = TextEditingController();
  final _ncm = TextEditingController();
  final _brand = TextEditingController();

  // preços
  final _price = TextEditingController(text: '0');      // unitário SEMPRE
  final _packPrice = TextEditingController(text: '0');  // preço da caixa (se CX)
  final _cost = TextEditingController(text: '0');
  final _margin = TextEditingController(text: '0');

  // embalagem
  final _packQty = TextEditingController(text: '0');    // itens/caixa

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

    // ligação unitário <-> pack
    _price.addListener(_syncPackFromUnit);
    _packQty.addListener(_syncPackFromUnit);
    _packPrice.addListener(_syncUnitFromPack);

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
    _packPrice.dispose();
    _cost.dispose();
    _margin.dispose();
    _packQty.dispose();
    _stock.dispose();
    _minStock.dispose();
    _maxStock.dispose();
    super.dispose();
  }

  // ======= PARSE de decimal robusto
  double _parseDecimal(String t) {
    var s = t.trim(); if (s.isEmpty) return 0.0;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    final hasComma = s.contains(','); final hasDot = s.contains('.');
    if (hasComma && hasDot) { s = s.replaceAll('.', '').replaceAll(',', '.'); }
    else if (hasComma) { s = s.replaceAll(',', '.'); }
    return double.tryParse(s) ?? 0.0;
  }

  // ======= PRECIFICAÇÃO
  void _fromCostMarginRecalcPrice() {
    if (_updating || !_autoPrice) return;
    _updating = true;
    final cost = _parseDecimal(_cost.text);
    final margin = _parseDecimal(_margin.text);
    final price = cost * (1 + margin / 100);
    _price.text = price.isFinite ? price.toStringAsFixed(2) : '0';
    _updating = false;
    setState(() {});
  }

  void _fromCostPriceRecalcMargin() {
    if (_updating) return;
    _updating = true;
    final cost = _parseDecimal(_cost.text);
    final price = _parseDecimal(_price.text);
    final margin = cost <= 0 ? 0 : ((price / cost) - 1) * 100;
    _margin.text = margin.isFinite ? margin.toStringAsFixed(2) : '0';
    _updating = false;
    setState(() {});
  }

  // ======= Unitário <-> Caixa
  void _syncPackFromUnit() {
    if (_updating) return;
    if (_unitKind != 'CX') return;
    _updating = true;
    final unitPrice = _parseDecimal(_price.text);
    final qty = (_parseDecimal(_packQty.text)).clamp(0, 999999).toDouble();
    if (qty > 0) {
      final pp = unitPrice * qty;
      _packPrice.text = pp.toStringAsFixed(2);
    } else {
      _packPrice.text = '0';
    }
    _updating = false;
  }

  void _syncUnitFromPack() {
    if (_updating) return;
    if (_unitKind != 'CX') return;
    _updating = true;
    final pp = _parseDecimal(_packPrice.text);
    final qty = (_parseDecimal(_packQty.text)).clamp(0, 999999).toDouble();
    if (qty > 0) {
      final unit = pp / qty;
      _price.text = unit.toStringAsFixed(2);
    }
    _updating = false;
  }

  // ======= LOAD
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
        _unitKind = (o.get<String>('unit') ?? 'UN').toUpperCase();
        _unit.text = _unitKind;

        _category.text = o.get<String>('category') ?? '';
        _ncm.text = o.get<String>('ncm') ?? '';
        _brand.text = o.get<String>('brand') ?? '';

        _price.text = ((o.get<num>('price') ?? 0).toDouble()).toStringAsFixed(2);
        _cost.text = ((o.get<num>('cost') ?? 0).toDouble()).toStringAsFixed(2);
        _margin.text = ((o.get<num>('margin') ?? 0).toDouble()).toStringAsFixed(2);

        _packQty.text = ((o.get<num>('packQty') ?? 0).toDouble()).toStringAsFixed(0);
        _packPrice.text = ((o.get<num>('packPrice') ?? 0).toDouble()).toStringAsFixed(2);

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
      // sempre espelha unidade escolhida no campo 'unit'
      _unit.text = _unitKind;

      await _repo.upsertProduct(
        objectId: _objectId,
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        barcode: bc.isEmpty ? null : bc,
        unit: _unit.text.trim(),
        price: _parseDecimal(_price.text),     // unitário
        cost: _parseDecimal(_cost.text),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        ncm: _ncm.text.trim().isEmpty ? null : _ncm.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        margin: _parseDecimal(_margin.text),
        stock: _parseDecimal(_stock.text),
        minStock: _parseDecimal(_minStock.text),
        maxStock: _parseDecimal(_maxStock.text),
        imageFile: _image,
        active: _active,
        // NOVOS CAMPOS
        packQty: _unitKind == 'CX' ? _parseDecimal(_packQty.text).round() : 0,
        packPrice: _unitKind == 'CX' ? _parseDecimal(_packPrice.text) : 0,
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
  // UI
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
      child: Text(_objectId == null ? 'Adicionar Produto' : 'Editar Produto',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
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
                    value: _unitKind,
                    items: const [
                      DropdownMenuItem(value: 'UN', child: Text('UN (Unidade)')),
                      DropdownMenuItem(value: 'CX', child: Text('CX (Caixa)')),
                      DropdownMenuItem(value: 'KG', child: Text('KG (Quilos)')),
                    ],
                    onChanged: (v) => setState(() => _unitKind = v ?? 'UN'),
                    decoration: const InputDecoration(labelText: 'Unidade *', border: OutlineInputBorder()),
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
                    controller: _brand,
                    decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
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
          height: 320,
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
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    labelText: _unitKind == 'CX' ? 'Preço Unitário (por item na CX)' : 'Preço de Venda',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _autoPrice = false,
                ),
              ),
            ],
          ),
          if (_unitKind == 'CX') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _packQty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Itens por caixa', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _packPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(prefixText: 'R\$ ', labelText: 'Preço da Caixa', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          if (_unitKind == 'KG') ...[
            const SizedBox(height: 8),
            Text('Vendido por KG: no PDV a quantidade permite frações (ex.: 0,150 kg).',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
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

  Widget _placeholder(String title) => Center(child: Text('$title — em breve'));
}
