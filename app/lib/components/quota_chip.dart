import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Indicatore di Quota: "N free AI requests left". Componente del design system, cablato
/// alle superfici AI in Fase 2/3. La Companion è sempre gratis e non lo mostra.
class QuotaChip extends StatelessWidget {
  const QuotaChip({super.key, required this.remaining});

  /// AI Request residue; `null` = illimitato.
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final exhausted = remaining != null && remaining! <= 0;
    final color = exhausted ? AppColors.lethal : AppColors.brand;
    final label = remaining == null ? 'AI illimitate' : '$remaining AI gratis';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
