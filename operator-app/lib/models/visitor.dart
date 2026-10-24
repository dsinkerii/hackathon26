class Visitor {
  const Visitor({
    required this.id,
    required this.status,
    required this.firstSeenAt,
    this.displayName,
    this.visitCount = 1,
    this.photoUrl,
  });

  final String id;
  final String status;
  final DateTime firstSeenAt;
  final String? displayName;
  final int visitCount;
  final String? photoUrl;

  bool get isPending => status == 'PENDING' || status == 'НА_РАССМОТРЕНИИ';

  factory Visitor.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    final firstSeenAt = json['firstSeenAt'];
    if (id == null || status is! String || firstSeenAt is! String) {
      throw const FormatException('Invalid visitor response');
    }

    final visitCount = json['visitCount'];
    return Visitor(
      id: id.toString(),
      status: status,
      firstSeenAt: DateTime.parse(firstSeenAt),
      displayName: json['displayName'] as String?,
      visitCount: visitCount is int ? visitCount : 1,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
