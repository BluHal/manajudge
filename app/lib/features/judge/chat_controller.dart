import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../api/models.dart';

/// Un messaggio nella chat del Judge.
class ChatMessage {
  const ChatMessage({
    required this.role, // 'user' | 'model'
    required this.text,
    this.meta,
    this.streaming = false,
    this.error,
  });

  final String role;
  final String text;
  final JudgeMeta? meta;
  final bool streaming;
  final String? error;

  bool get fromUser => role == 'user';

  ChatMessage copyWith({String? text, JudgeMeta? meta, bool? streaming, String? error}) =>
      ChatMessage(
        role: role,
        text: text ?? this.text,
        meta: meta ?? this.meta,
        streaming: streaming ?? this.streaming,
        error: error ?? this.error,
      );
}

/// Stato e logica della chat del Judge: multi-turno, risposta in streaming, fonti citate.
/// Ogni turno inviato è una AI Request (conteggio lato Backend).
class ChatController extends Notifier<List<ChatMessage>> {
  bool _busy = false;
  bool get isBusy => _busy;

  @override
  List<ChatMessage> build() => const [];

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    _busy = true;

    // history = i turni precedenti (prima di questo), nel formato del Backend.
    final history = [for (final m in state) {'role': m.role, 'text': m.text}];

    state = [
      ...state,
      ChatMessage(role: 'user', text: trimmed),
      const ChatMessage(role: 'model', text: '', streaming: true),
    ];

    try {
      await for (final chunk in ref.read(apiClientProvider).streamJudge(trimmed, history)) {
        switch (chunk) {
          case MetaChunk(:final meta):
            _updateLast((m) => m.copyWith(meta: meta));
          case TextChunk(:final text):
            _updateLast((m) => m.copyWith(text: m.text + text));
        }
      }
      _updateLast((m) => m.copyWith(streaming: false));
    } catch (e) {
      _updateLast((m) => m.copyWith(streaming: false, error: e.toString()));
    } finally {
      _busy = false;
    }
  }

  void reset() {
    if (_busy) return;
    state = const [];
  }

  void _updateLast(ChatMessage Function(ChatMessage) update) {
    if (state.isEmpty) return;
    final next = [...state];
    next[next.length - 1] = update(next.last);
    state = next;
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, List<ChatMessage>>(ChatController.new);
