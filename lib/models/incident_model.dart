enum IncidentType {
  carOnPlayground,
  strangerDetected,
  doorOpened,
  deliveryArrived,
  motionDetected,
}

extension IncidentTypeExtension on IncidentType {
  String get code {
    switch (this) {
      case IncidentType.carOnPlayground:
        return 'CAR_ON_PLAYGROUND';
      case IncidentType.strangerDetected:
        return 'STRANGER_DETECTED';
      case IncidentType.doorOpened:
        return 'DOOR_OPENED';
      case IncidentType.deliveryArrived:
        return 'DELIVERY_ARRIVED';
      case IncidentType.motionDetected:
        return 'MOTION_DETECTED';
    }
  }

  String get labelRu {
    switch (this) {
      case IncidentType.carOnPlayground:
        return 'Авто на площадке';
      case IncidentType.strangerDetected:
        return 'Незнакомец';
      case IncidentType.doorOpened:
        return 'Дверь открыта';
      case IncidentType.deliveryArrived:
        return 'Доставка';
      case IncidentType.motionDetected:
        return 'Движение';
    }
  }

  static IncidentType fromCode(String code) {
    switch (code) {
      case 'CAR_ON_PLAYGROUND':
        return IncidentType.carOnPlayground;
      case 'STRANGER_DETECTED':
        return IncidentType.strangerDetected;
      case 'DOOR_OPENED':
        return IncidentType.doorOpened;
      case 'DELIVERY_ARRIVED':
        return IncidentType.deliveryArrived;
      default:
        return IncidentType.motionDetected;
    }
  }
}

class StrangerInfo {
  final int id;
  final String? bestSnapshotUrl;
  final int visitCount;
  final DateTime firstSeen;
  final DateTime lastSeen;

  const StrangerInfo({
    required this.id,
    this.bestSnapshotUrl,
    required this.visitCount,
    required this.firstSeen,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bestSnapshotUrl': bestSnapshotUrl,
        'visitCount': visitCount,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory StrangerInfo.fromJson(Map<String, dynamic> json) => StrangerInfo(
        id: json['id'] as int,
        bestSnapshotUrl: json['bestSnapshotUrl'] as String?,
        visitCount: json['visitCount'] as int? ?? 1,
        firstSeen: DateTime.parse(json['firstSeen'] as String),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
      );
}

class Incident {
  final int id;
  final IncidentType type;
  final DateTime occurredAt;
  final String description;
  final String? snapshotUrl;
  final double? confidence;
  final bool processed;
  final DateTime? processedAt;
  final StrangerInfo? stranger;

  const Incident({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.description,
    this.snapshotUrl,
    this.confidence,
    this.processed = false,
    this.processedAt,
    this.stranger,
  });

  Incident copyWith({
    bool? processed,
    DateTime? processedAt,
  }) {
    return Incident(
      id: id,
      type: type,
      occurredAt: occurredAt,
      description: description,
      snapshotUrl: snapshotUrl,
      confidence: confidence,
      processed: processed ?? this.processed,
      processedAt: processedAt ?? this.processedAt,
      stranger: stranger,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.code,
        'occurredAt': occurredAt.toIso8601String(),
        'description': description,
        'snapshotUrl': snapshotUrl,
        'confidence': confidence,
        'processed': processed,
        'processedAt': processedAt?.toIso8601String(),
        'stranger': stranger?.toJson(),
      };

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as int,
        type: IncidentTypeExtension.fromCode(json['type'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        description: json['description'] as String,
        snapshotUrl: json['snapshotUrl'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        processed: json['processed'] as bool? ?? false,
        processedAt: json['processedAt'] != null
            ? DateTime.parse(json['processedAt'] as String)
            : null,
        stranger: json['stranger'] != null
            ? StrangerInfo.fromJson(json['stranger'] as Map<String, dynamic>)
            : null,
      );
}
