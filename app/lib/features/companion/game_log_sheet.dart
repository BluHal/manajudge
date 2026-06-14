import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/tokens.dart';

/// Bottom sheet che mostra il Game log (cambi di vita/counter in ordine), per risolvere
/// "quant'era il mio totale?". Più recente in alto.
class GameLogSheet extends StatelessWidget {
  const GameLogSheet({super.key, required this.log});

  final List<LogEntry> log;

  static void show(BuildContext context, List<LogEntry> log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GameLogSheet(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = log.reversed.toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Align(alignment: Alignment.centerLeft, child: Text('Game log', style: theme.textTheme.titleLarge)),
            ),
            if (entries.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Text('Ancora nessun evento.'))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.describe()),
                      trailing: Text(_time(e.timestamp), style: theme.textTheme.bodySmall),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
