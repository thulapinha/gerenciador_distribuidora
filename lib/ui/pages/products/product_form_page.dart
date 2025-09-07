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

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductRepository();

  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'UN');
  final _category = TextEditingController();
  final _ncm = TextEditingController();
  final _brand = TextEditingController();

  final _price = TextEditingController(text: '0');
  final _cost = TextEditingController(text: '0');
  final _margin = TextEditingController(text: '0');

  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _maxStock = TextEditingController(text: '0');

  bool _active = true;
  ParseFileBase? _image;
  String? _objectId;
  bool _saving = false;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _cost.addListener(_fromCostMarginRecalcPrice);
    _margin.addListener(_fromCostMarginRecalcPrice);
    _price.addListener(_fromCostPriceRecalcMargin);
    _load();
  }

  @override
  void dispose() {
    _cost.removeListener(_fromCostMarginRecalcPrice);
    _margin.removeListener(_fromCostMarginRecalcPrice);
    _price.removeListener(_fromCostPriceRecalcMargin);

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

  double _toD(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  void _fromCostMarginRecalcPrice() {
    if (_updating) return;
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
        _margin.text = ((o.get<num>('margin') ?? 0).toDouble()).toString();
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
      type: FileType.image,
      allowMultiple: false,
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
    setState(() => _saving = true);
    try {
      await _repo.upsertProduct(
        objectId: _objectId,
        name: _name.text.trim(),
        sku: _sku.text.trim(),
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'UN' : _unit.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        ncm: _ncm.text.trim().isEmpty ? null : _ncm.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        price: _toD(_price),
        cost: _toD(_cost),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_objectId == null ? 'Novo produto' : 'Editar produto')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'SKU *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o SKU' : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Unidade *'),
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
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Código de barras'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Categoria'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ncm,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'NCM'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Preço (R\$) *'),
                    validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) == null) ? 'Valor inválido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Custo (R\$)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _margin,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Margem (%)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brand,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Marca'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Imagem'),
                ),
                if (_image != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle, color: Colors.teal),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Estoque'),
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Ativo'),
                const SizedBox(width: 8),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
