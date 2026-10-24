class VideoRecording {
  const VideoRecording({
    required this.id,
    this.cameraId,
    this.cameraName,
    required this.title,
    required this.recordedAt,
    required this.videoUrl,
    this.eventType,
    this.durationSeconds,
  });

  final String id;

  /// Null for entries of the hidden «Без камеры» category (admins only).
  final String? cameraId;
  final String? cameraName;
  final String title;
  final DateTime recordedAt;
  final String videoUrl;
  final String? eventType;
  final int? durationSeconds;

  factory VideoRecording.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final cameraId = json['cameraId'];
    final cameraName = json['cameraName'];
    final title = json['title'];
    final recordedAt = json['recordedAt'];
    final videoUrl = json['videoUrl'];
    if (id is! String ||
        (cameraId != null && cameraId is! String) ||
        (cameraName != null && cameraName is! String) ||
        title is! String ||
        recordedAt is! String ||
        videoUrl is! String) {
      throw const FormatException('Invalid recording response');
    }
    return VideoRecording(
      id: id,
      cameraId: cameraId as String?,
      cameraName: cameraName as String?,
      title: title,
      recordedAt: DateTime.parse(recordedAt),
      videoUrl: videoUrl,
      eventType: json['eventType'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}
