import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../components/card_result_row.dart';
import '../../theme/tokens.dart';
import 'search_controller.dart';

/// La superficie **Card Search**: query in linguaggio naturale -> lista rankata di carte
/// reali (nessuna carta inventata). Ogni ricerca = 1 AI Request.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search() => ref.read(searchControllerProvider.notifier).search(_input.text);

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(searchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Card Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Es. "carte che copiano gli spell avversari"',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ),
            ),
          ),
          Expanded(child: _body(context, result)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<List<CardHit>>? result) {
    if (result == null) {
      return const _SearchHint();
    }
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Centered(
        icon: Icons.error_outline,
        color: AppColors.lethal,
        title: 'Errore nella ricerca',
        subtitle: '$e',
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return const _Centered(
            icon: Icons.search_off,
            title: 'Nessuna carta trovata',
            subtitle: 'Prova a riformulare la query.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: cards.length,
          itemBuilder: (_, i) {
            final c = cards[i];
            return CardResultRow(
              name: c.name,
              typeLine: c.typeLine,
              manaCost: c.manaCost,
              oracleText: c.oracleText,
            );
          },
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) => const _Centered(
        icon: Icons.search,
        title: 'Cerca carte per effetto',
        subtitle: 'Descrivi cosa fa la carta, in linguaggio naturale.',
      );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.title, required this.subtitle, this.color});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color ?? AppColors.brand),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
