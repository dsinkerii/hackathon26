class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.description,
    this.snapshotUrl,
  });

  final String id;
  final String type;
  final DateTime occurredAt;
  final String? description;
  final String? snapshotUrl;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: _requiredString(json, 'id'),
      type: _requiredString(json, 'type'),
      occurredAt: DateTime.parse(_requiredString(json, 'occurredAt')),
      description: json['description'] as String?,
      snapshotUrl: json['snapshotUrl'] as String?,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  throw FormatException('Missing or invalid "$key" field');
}
