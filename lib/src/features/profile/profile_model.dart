class StudentProfile {
  final String sub;
  final String username;
  final String displayName;
  final String email;
  final String role;

  StudentProfile({
    required this.sub,
    required this.username,
    required this.displayName,
    required this.email,
    required this.role,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      sub: json['sub'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}
