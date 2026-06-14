import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Bolla di chat del **Judge**. La risposta del giudice usa il corpo "documento" (serif,
/// autorevole); la domanda dell'utente un trattamento più leggero. Componente del design
/// system; il wiring streaming arriva in Fase 2.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.surfaceHigh : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(text, style: fromUser ? null : AppTypography.judgeBody),
      ),
    );
  }
}

/// Blocco "fonte citata": numero di regola + testo, visivamente distinto e verificabile.
/// Sempre mostrato sotto una risposta del Judge.
class CitedSourceBlock extends StatelessWidget {
  const CitedSourceBlock({super.key, required this.reference, required this.text});

  /// Es. "601.2a" oppure il nome della carta citata.
  final String reference;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: const Border(left: BorderSide(color: AppColors.brand, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reference, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          Text(text, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
