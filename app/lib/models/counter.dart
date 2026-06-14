/// Un contatore generico per-Seat (energia, esperienza, tesori, ...). Etichetta + valore.
class GameCounter {
  const GameCounter({required this.id, required this.label, this.value = 0});

  final String id;
  final String label;
  final int value;

  GameCounter copyWith({String? label, int? value}) =>
      GameCounter(id: id, label: label ?? this.label, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'value': value};

  factory GameCounter.fromJson(Map<String, dynamic> json) => GameCounter(
        id: json['id'] as String,
        label: json['label'] as String,
        value: json['value'] as int,
      );
}
