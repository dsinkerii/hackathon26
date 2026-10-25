class Camera {
  const Camera({
    required this.id,
    required this.name,
    this.location,
    this.streamUrl,
    required this.enabled,
  });

  final String id;
  final String name;
  final String? location;
  final String? streamUrl;
  final bool enabled;

  factory Camera.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException('Invalid camera response');
    }
    return Camera(
      id: id,
      name: name,
      location: json['location'] as String?,
      streamUrl: json['streamUrl'] as String?,
      enabled: json['enabled'] == true,
    );
  }
}
