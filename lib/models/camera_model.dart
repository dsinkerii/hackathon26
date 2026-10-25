class CameraFeed {
  final String id;
  final String name;
  final String address;
  final String snapshotAsset;
  final String streamUrl;
  final bool isOnline;
  final bool isRecording;
  final DateTime lastPing;
  final bool doorLocked;

  const CameraFeed({
    required this.id,
    required this.name,
    required this.address,
    required this.snapshotAsset,
    required this.streamUrl,
    this.isOnline = true,
    this.isRecording = true,
    required this.lastPing,
    this.doorLocked = true,
  });

  CameraFeed copyWith({
    bool? isOnline,
    bool? isRecording,
    bool? doorLocked,
    DateTime? lastPing,
  }) {
    return CameraFeed(
      id: id,
      name: name,
      address: address,
      snapshotAsset: snapshotAsset,
      streamUrl: streamUrl,
      isOnline: isOnline ?? this.isOnline,
      isRecording: isRecording ?? this.isRecording,
      lastPing: lastPing ?? this.lastPing,
      doorLocked: doorLocked ?? this.doorLocked,
    );
  }
}
