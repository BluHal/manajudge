import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Riga di risultato della **Card Search**: nome carta + info rilevanti (tipo, costo, testo).
/// Componente del design system; il wiring alla ricerca del Backend arriva in Fase 2.
class CardResultRow extends StatelessWidget {
  const CardResultRow({
    super.key,
    required this.name,
    this.typeLine,
    this.manaCost,
    this.oracleText,
  });

  final String name;
  final String? typeLine;
  final String? manaCost;
  final String? oracleText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
            if (manaCost != null && manaCost!.isNotEmpty)
              Text(manaCost!, style: theme.textTheme.bodySmall),
          ]),
          if (typeLine != null && typeLine!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(typeLine!, style: theme.textTheme.bodySmall),
          ],
          if (oracleText != null && oracleText!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(oracleText!, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
