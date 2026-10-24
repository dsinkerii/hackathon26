class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  final String accessToken;
  final String username;
  final String role;
  final DateTime expiresAt;

  bool get isAdmin => role == 'ADMIN';

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    final username = json['username'];
    final role = json['role'];
    final expiresAt = json['expiresAt'];
    if (token is! String ||
        username is! String ||
        role is! String ||
        expiresAt is! String) {
      throw const FormatException('Invalid login response');
    }
    return AdminSession(
      accessToken: token,
      username: username,
      role: role,
      expiresAt: DateTime.parse(expiresAt),
    );
  }
}
