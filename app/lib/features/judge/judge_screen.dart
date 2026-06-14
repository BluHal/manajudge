import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/chat_bubble.dart';
import '../../theme/tokens.dart';
import 'chat_controller.dart';

/// La superficie **Judge**: chat multi-turno con risposta in streaming e fonti citate
/// sempre mostrate (numeri di regola + oracle text delle carte). Ogni turno = 1 AI Request.
class JudgeScreen extends ConsumerStatefulWidget {
  const JudgeScreen({super.key});

  @override
  ConsumerState<JudgeScreen> createState() => _JudgeScreenState();
}

class _JudgeScreenState extends ConsumerState<JudgeScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatControllerProvider);
    final busy = messages.isNotEmpty && messages.last.streaming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge'),
        actions: [
          IconButton(
            tooltip: 'Nuova conversazione',
            onPressed: busy ? null : () => ref.read(chatControllerProvider.notifier).reset(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const _EmptyJudge()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageView(message: messages[i]),
                  ),
          ),
          _InputBar(controller: _input, onSend: _send, enabled: !busy),
        ],
      ),
    );
  }
}

class _EmptyJudge extends StatelessWidget {
  const _EmptyJudge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.balance_outlined, size: 40, color: AppColors.brand),
            const SizedBox(height: AppSpacing.md),
            Text('Chiedi una regola o un’interazione.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Risposta citata da regole ufficiali e testo delle carte.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return ChatBubble(text: message.text, fromUser: true);
    }

    final meta = message.meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.isEmpty && message.streaming)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          ChatBubble(text: message.text, fromUser: false),
        if (message.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('⚠️ ${message.error}', style: const TextStyle(color: AppColors.lethal)),
          ),
        if (meta != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _ConfidenceChip(confidence: meta.confidence),
          const SizedBox(height: AppSpacing.xs),
          for (final s in meta.sources)
            CitedSourceBlock(reference: s.reference, text: s.text),
          for (final c in meta.cards)
            CitedSourceBlock(reference: c.name, text: c.oracleText ?? c.typeLine ?? ''),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'alta' => AppColors.success,
      'bassa' => AppColors.lethal,
      _ => AppColors.warning,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_outlined, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text('Confidenza $confidence', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, required this.enabled});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: const InputDecoration(
                  hintText: 'Chiedi al giudice…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
