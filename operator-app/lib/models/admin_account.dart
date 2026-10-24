class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.username,
    required this.role,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String role;
  final bool enabled;
  final DateTime createdAt;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    final role = json['role'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        username is! String ||
        role is! String ||
        createdAt is! String) {
      throw const FormatException('Invalid account response');
    }
    return AdminAccount(
      id: id,
      username: username,
      role: role,
      enabled: json['enabled'] == true,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
