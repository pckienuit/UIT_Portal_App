class StudentSupportResponse {
  StudentSupportResponse({
    required this.tickets,
    required this.teams,
  });

  final List<dynamic> tickets;
  final List<SupportTeam> teams;

  factory StudentSupportResponse.fromJson(Map<String, dynamic> json) {
    return StudentSupportResponse(
      tickets: _parseList(json['tickets'], (e) => e),
      teams: _parseList(json['teams'], (e) => SupportTeam.fromJson(e)),
    );
  }

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    } else if (data is Map) {
      return data.values.whereType<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    }
    return [];
  }
}

class SupportTeam {
  SupportTeam({
    this.id,
    this.name,
    this.code,
    this.teamNote,
  });

  final int? id;
  final String? name;
  final String? code;
  final String? teamNote;

  factory SupportTeam.fromJson(Map<String, dynamic> json) {
    return SupportTeam(
      id: json['id'] as int?,
      name: json['name'] as String?,
      code: json['code'] as String?,
      teamNote: json['teamNote'] as String?,
    );
  }
}
