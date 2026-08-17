class MoodleDeadline {
  const MoodleDeadline({
    required this.id,
    required this.name,
    required this.courseName,
    required this.courseCode,
    required this.deadlineTime,
    required this.isOverdue,
    this.actionUrl,
    this.actionName,
    this.isCompleted = false,
  });

  factory MoodleDeadline.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    final action = json['action'] as Map<String, dynamic>?;

    final name = (json['activityname'] ?? json['name'] ?? '') as String;
    final cleanName = name
        .replaceAll(RegExp(r'\s+tới hạn$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+is due$', caseSensitive: false), '')
        .trim();

    final timesort = json['timesort'] as int? ?? json['timestart'] as int? ?? 0;
    final deadlineTime = DateTime.fromMillisecondsSinceEpoch(timesort * 1000);

    final now = DateTime.now();
    final overdueBool = json['overdue'] as bool? ?? deadlineTime.isBefore(now);

    // Moodle logic: nếu action.actionable == false và action.name != 'Thêm bài nộp' hoặc actionUrl dẫn tới view đã nộp
    // hoặc eventtype/action cho thấy đã nộp
    final actionName = action?['name'] as String?;
    final actionUrl = action?['url'] as String? ?? json['url'] as String?;
    
    // Nếu sinh viên đã hoàn thành hoặc không còn actionable
    final isCompleted = action != null &&
        action['actionable'] == false &&
        (actionName?.contains('Đã nộp') == true ||
            actionName?.contains('Xem bài nộp') == true ||
            actionName?.contains('Xem tổng quan') == true);

    return MoodleDeadline(
      id: json['id'] as int? ?? 0,
      name: cleanName.isNotEmpty ? cleanName : name,
      courseName: (course?['fullname'] ?? '') as String,
      courseCode: (course?['shortname'] ?? '') as String,
      deadlineTime: deadlineTime,
      isOverdue: overdueBool,
      actionUrl: actionUrl,
      actionName: actionName,
      isCompleted: isCompleted,
    );
  }

  final int id;
  final String name;
  final String courseName;
  final String courseCode;
  final DateTime deadlineTime;
  final bool isOverdue;
  final String? actionUrl;
  final String? actionName;
  final bool isCompleted;

  /// Trạng thái phân loại: upcoming (chưa tới hạn), overdue (đã quá hạn), completed (đã hoàn thành)
  DeadlineStatus get status {
    if (isCompleted) return DeadlineStatus.completed;
    if (deadlineTime.isBefore(DateTime.now()) || isOverdue) {
      return DeadlineStatus.overdue;
    }
    return DeadlineStatus.upcoming;
  }
}

enum DeadlineStatus {
  upcoming,
  overdue,
  completed,
}
