enum PersonalNotificationType {
  schedule, // Nhắc lịch học
  parking,  // Nhắc hết hạn gửi xe
  grades,   // Điểm số mới
  tuition,  // Học phí mới
  general,  // Thông báo khác
}

class PersonalNotificationItem {
  const PersonalNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.targetRoute,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final PersonalNotificationType type;
  final String? targetRoute;
  final bool isRead;

  PersonalNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    PersonalNotificationType? type,
    String? targetRoute,
    bool? isRead,
  }) {
    return PersonalNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      targetRoute: targetRoute ?? this.targetRoute,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'targetRoute': targetRoute,
      'isRead': isRead,
    };
  }

  factory PersonalNotificationItem.fromJson(Map<String, dynamic> json) {
    return PersonalNotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      type: PersonalNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PersonalNotificationType.general,
      ),
      targetRoute: json['targetRoute'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
