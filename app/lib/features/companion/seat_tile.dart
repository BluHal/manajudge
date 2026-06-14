import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/seat.dart';
import '../../state/game_controller.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Tile di un Seat: la vita come elemento dominante (numero oversize), con l'accento mana
/// del Seat. Tap nella metà alta = +1 / bassa = -1; long-press = ±5; swipe orizzontale = ±10.
/// Tocca l'icona per aprire i tracker (commander damage, veleno, counter).
class SeatTile extends ConsumerWidget {
  const SeatTile({super.key, required this.seat, required this.compact, required this.onOpenDetail});

  final Seat seat;
  final bool compact;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final accent = seat.manaColor.accent;
    final lethal = seat.poisonLethal || seat.commanderLethal;

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity;
        if (v == null || v == 0) return;
        controller.adjustLife(seat.id, v > 0 ? 10 : -10);
      },
      child: Container(
        decoration: BoxDecoration(
          color: seat.manaColor.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: lethal ? AppColors.lethal : accent.withValues(alpha: 0.6), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(context, accent),
            Expanded(
              child: Stack(
                children: [
                  // Zone di tap: metà alta = +, metà bassa = -.
                  Column(
                    children: [
                      Expanded(child: _tapZone(controller, delta: 1, longDelta: 5, align: Alignment.topCenter, icon: Icons.add)),
                      Expanded(child: _tapZone(controller, delta: -1, longDelta: -5, align: Alignment.bottomCenter, icon: Icons.remove)),
                    ],
                  ),
                  // Numero vita al centro (ignora i tocchi, che passano alle zone sotto).
                  IgnorePointer(
                    child: Center(
                      child: Text(
                        '${seat.life}',
                        style: (compact ? AppTypography.lifeNumberCompact : AppTypography.lifeNumber)
                            .copyWith(color: seat.isDead ? AppColors.onSurfaceMuted : AppColors.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _statusBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
      child: Row(
        children: [
          CircleAvatar(radius: 9, backgroundColor: accent, child: Text(
            seat.manaColor.symbol,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(seat.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: onOpenDetail,
            icon: const Icon(Icons.tune),
            tooltip: 'Commander damage, veleno, counter',
          ),
        ],
      ),
    );
  }

  Widget _tapZone(GameController controller,
      {required int delta, required int longDelta, required Alignment align, required IconData icon}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.adjustLife(seat.id, delta),
      onLongPress: () => controller.adjustLife(seat.id, longDelta),
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, size: 18, color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }

  Widget _statusBar(BuildContext context) {
    final chips = <Widget>[];
    if (seat.poison > 0) {
      chips.add(_miniChip('☠ ${seat.poison}', seat.poisonLethal));
    }
    if (seat.maxCommanderDamage > 0) {
      chips.add(_miniChip('⚔ ${seat.maxCommanderDamage}', seat.commanderLethal));
    }
    for (final c in seat.counters) {
      chips.add(_miniChip('${c.label} ${c.value}', false));
    }
    if (chips.isEmpty) return const SizedBox(height: AppSpacing.sm);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, alignment: WrapAlignment.center, children: chips),
    );
  }

  Widget _miniChip(String label, bool lethal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: lethal ? AppColors.lethal.withValues(alpha: 0.18) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: lethal ? AppColors.lethal : AppColors.onSurfaceMuted)),
    );
  }
}
