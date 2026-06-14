import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../api/models.dart';

/// Stato della Card Search. `null` = nessuna ricerca ancora fatta (idle); altrimenti
/// loading / lista carte / errore.
class SearchController extends Notifier<AsyncValue<List<CardHit>>?> {
  String _lastQuery = '';
  String get lastQuery => _lastQuery;

  @override
  AsyncValue<List<CardHit>>? build() => null;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _lastQuery = trimmed;
    state = const AsyncValue.loading();
    try {
      final cards = await ref.read(apiClientProvider).searchCards(trimmed);
      state = AsyncValue.data(cards);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, AsyncValue<List<CardHit>>?>(SearchController.new);
