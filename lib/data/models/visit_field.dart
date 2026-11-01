enum FieldType { text, multiline, number, currency, date, photo, toggle, selector }

/// Visit fields whose values live in dedicated `visits` columns. Everything
/// else is stored in `visits.custom_fields` keyed by [VisitFieldDefinition.key].
const builtInVisitKeys = {'outcome', 'contactName', 'phone', 'email', 'notes', 'followUpDate', 'photo'};

class VisitFieldDefinition {
  const VisitFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.enabled = true,
    this.isCustom = false,
    this.options = const [],
    this.hint,
  });

  final String key;
  final String label;
  final FieldType type;
  final bool enabled;
  final bool isCustom;
  final List<String> options;
  final String? hint;

  bool get isBuiltIn => builtInVisitKeys.contains(key);

  VisitFieldDefinition copyWith({String? label, bool? enabled, FieldType? type, List<String>? options}) =>
      VisitFieldDefinition(
        key: key,
        label: label ?? this.label,
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
        isCustom: isCustom,
        options: options ?? this.options,
        hint: hint,
      );

  factory VisitFieldDefinition.fromJson(Map<String, dynamic> j) => VisitFieldDefinition(
        key: j['key'] as String,
        label: j['label'] as String,
        type: FieldType.values.firstWhere((t) => t.name == j['type'], orElse: () => FieldType.text),
        enabled: j['enabled'] as bool? ?? true,
        isCustom: j['isCustom'] as bool? ?? false,
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        hint: j['hint'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'enabled': enabled,
        'isCustom': isCustom,
        'options': options,
        if (hint != null) 'hint': hint,
      };
}
