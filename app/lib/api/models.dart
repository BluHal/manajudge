/// Una carta reale ritornata dalla Card Search (`/api/search`). Nessuna carta inventata:
/// vengono dal DB del Backend.
class CardHit {
  const CardHit({
    required this.oracleId,
    required this.name,
    this.manaCost,
    this.typeLine,
    this.oracleText,
    this.power,
    this.toughness,
    this.loyalty,
    this.similarity = 0,
  });

  final String oracleId;
  final String name;
  final String? manaCost;
  final String? typeLine;
  final String? oracleText;
  final String? power;
  final String? toughness;
  final String? loyalty;
  final double similarity;

  factory CardHit.fromJson(Map<String, dynamic> json) => CardHit(
        oracleId: (json['oracle_id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        manaCost: json['mana_cost'] as String?,
        typeLine: json['type_line'] as String?,
        oracleText: json['oracle_text'] as String?,
        power: json['power'] as String?,
        toughness: json['toughness'] as String?,
        loyalty: json['loyalty'] as String?,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
      );
}

/// Una fonte citata dal Judge: numero di regola (o nome carta) + testo, sempre mostrata e
/// verificabile.
class CitedSource {
  const CitedSource({required this.reference, required this.headerPath, required this.text});

  final String reference; // rule_id (es. "601.2a")
  final String headerPath;
  final String text;

  factory CitedSource.fromJson(Map<String, dynamic> json) => CitedSource(
        reference: (json['rule_id'] ?? '') as String,
        headerPath: (json['header_path'] ?? '') as String,
        text: (json['text'] ?? '') as String,
      );
}

/// L'oracle text di una carta citata nella risposta del Judge.
class CitedCard {
  const CitedCard({required this.name, this.typeLine, this.oracleText});

  final String name;
  final String? typeLine;
  final String? oracleText;

  factory CitedCard.fromJson(Map<String, dynamic> json) => CitedCard(
        name: (json['name'] ?? '') as String,
        typeLine: json['type_line'] as String?,
        oracleText: json['oracle_text'] as String?,
      );
}

/// I metadati che precedono la risposta in streaming del Judge (prima riga di `/api/chat`).
class JudgeMeta {
  const JudgeMeta({
    required this.rewritten,
    required this.confidence,
    required this.cards,
    required this.sources,
  });

  final String rewritten;
  final String confidence; // 'alta' | 'media' | 'bassa'
  final List<CitedCard> cards;
  final List<CitedSource> sources;

  factory JudgeMeta.fromJson(Map<String, dynamic> json) => JudgeMeta(
        rewritten: (json['rewritten'] ?? '') as String,
        confidence: (json['confidence'] ?? 'media') as String,
        cards: ((json['cards'] as List<dynamic>?) ?? [])
            .map((c) => CitedCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        sources: ((json['sources'] as List<dynamic>?) ?? [])
            .map((s) => CitedSource.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// Un frammento dello stream del Judge: o i metadati (prima riga) o testo della risposta.
sealed class ChatChunk {
  const ChatChunk();
}

class MetaChunk extends ChatChunk {
  const MetaChunk(this.meta);
  final JudgeMeta meta;
}

class TextChunk extends ChatChunk {
  const TextChunk(this.text);
  final String text;
}

/// Errore di superficie AI con un messaggio mostrabile e l'eventuale codice HTTP.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  /// Quota esaurita (gestita davvero in #12; qui solo riconosciuta).
  bool get isQuotaExhausted => statusCode == 402;

  @override
  String toString() => message;
}
