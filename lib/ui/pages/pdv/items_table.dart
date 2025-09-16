// lib/ui/pages/pdv/items_table.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Items Table ===========================================================
class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onInc,
    required this.onDec,
    required this.onEditQty,
    required this.onEditUnit,
    required this.onRemove,
  });
  final List<_PdvItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onInc;
  final ValueChanged<int> onDec;
  final ValueChanged<int> onEditQty;
  final ValueChanged<int> onEditUnit;
  final ValueChanged<int> onRemove;

  String _money(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _fmtQty(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  _HCell(width: 64, child: Text('Nº', style: headerStyle)),
                  _HCell(flex: 3, child: Text('Nome do Produto', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Quantidade (F4)', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Valor Unitário (F5)', style: headerStyle)),
                  _HCell(flex: 2, child: Text('Valor Total', style: headerStyle)),
                  _HCell(width: 56, child: const SizedBox()),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Nenhum item adicionado'))
                  : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final selected = i == selectedIndex;
                  return InkWell(
                    onTap: () => onSelect(i),
                    child: Container(
                      color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _HCell(width: 64, child: Text('${i + 1}')),
                          _HCell(
                            flex: 3,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: it.imageUrl != null
                                      ? Image.network(it.imageUrl!, width: 36, height: 36, fit: BoxFit.cover)
                                      : Container(
                                    width: 36,
                                    height: 36,
                                    color: Colors.black12,
                                    child: const Icon(Icons.inventory_2, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: Row(
                              children: [
                                IconButton(onPressed: () => onDec(i), icon: const Icon(Icons.remove_circle_outline)),
                                GestureDetector(
                                  onTap: () => onEditQty(i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_fmtQty(it.qty)),
                                  ),
                                ),
                                IconButton(onPressed: () => onInc(i), icon: const Icon(Icons.add_circle_outline)),
                              ],
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () => onEditUnit(i),
                              child: Align(alignment: Alignment.centerLeft, child: Text(_money(it.unitPrice))),
                            ),
                          ),
                          _HCell(
                            flex: 2,
                            child: Text(_money(it.qty * it.unitPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          _HCell(width: 56, child: IconButton(onPressed: () => onRemove(i), icon: const Icon(Icons.delete_outline))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  const _HCell({this.flex, this.width, required this.child});
  final int? flex;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Align(alignment: Alignment.centerLeft, child: child);
    if (width != null) return SizedBox(width: width, child: content);
    return Expanded(flex: flex ?? 1, child: content);
  }
}
