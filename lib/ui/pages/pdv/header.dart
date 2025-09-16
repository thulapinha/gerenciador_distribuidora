// lib/ui/pages/pdv/header.dart
part of 'package:gerenciador_distribuidora/ui/pages/pdv_page.dart';

// ===== Header / Steps ========================================================
class _Header extends StatelessWidget {
  const _Header({required this.priceTier, required this.stage});
  final String priceTier;
  final _PdvStage stage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color dot(bool active) => active ? Colors.white : Colors.white.withOpacity(.55);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.95), cs.primaryContainer.withOpacity(.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text('$_Header', style: const TextStyle(fontSize: 0)), // evita warning
          const SizedBox(height: 4),
          const Text('Preço Padrão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            children: [
              _StepDot(label: 'Nova venda', color: dot(stage == _PdvStage.items)),
              _StepDot(label: 'Forma de pagamento', color: dot(stage == _PdvStage.payment)),
              _StepDot(label: 'Finalizar venda', color: dot(stage == _PdvStage.finish)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
