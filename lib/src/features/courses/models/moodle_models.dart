class MoodleCourse {
  const MoodleCourse({
    required this.id,
    required this.fullname,
    required this.shortname,
    this.idnumber,
    this.summary,
    this.viewUrl,
    this.courseImage,
    this.progress,
    this.hasCompleted = false,
  });

  final int id;
  final String fullname;
  final String shortname;
  final String? idnumber;
  final String? summary;
  final String? viewUrl;
  final String? courseImage;
  final int? progress;
  final bool hasCompleted;

  factory MoodleCourse.fromJson(Map<String, dynamic> json) {
    return MoodleCourse(
      id: json['id'] as int? ?? 0,
      fullname: json['fullname']?.toString() ?? '',
      shortname: json['shortname']?.toString() ?? '',
      idnumber: json['idnumber']?.toString(),
      summary: json['summary']?.toString(),
      viewUrl: json['viewurl']?.toString(),
      courseImage: json['courseimage']?.toString(),
      progress: json['progress'] as int?,
      hasCompleted: json['hascompleted'] == true,
    );
  }
}

class MoodleDeadline {
  const MoodleDeadline({
    required this.id,
    required this.name,
    required this.courseName,
    required this.courseId,
    this.description,
    this.activityName,
    this.url,
    this.timesort,
    this.formattedTime,
    this.actionName,
    this.actionUrl,
  });

  final int id;
  final String name;
  final String courseName;
  final int courseId;
  final String? description;
  final String? activityName;
  final String? url;
  final int? timesort;
  final String? formattedTime;
  final String? actionName;
  final String? actionUrl;

  factory MoodleDeadline.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>?;
    final action = json['action'] as Map<String, dynamic>?;

    return MoodleDeadline(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      courseName: course?['fullname']?.toString() ?? json['course_name']?.toString() ?? '',
      courseId: course?['id'] as int? ?? json['course_id'] as int? ?? 0,
      description: json['description']?.toString(),
      activityName: json['activityname']?.toString(),
      url: json['url']?.toString(),
      timesort: json['timesort'] as int?,
      formattedTime: json['formattedtime']?.toString(),
      actionName: action?['name']?.toString(),
      actionUrl: action?['url']?.toString(),
    );
  }
}

class MoodleActivity {
  const MoodleActivity({
    required this.id,
    required this.name,
    required this.type, // forum, folder, resource, assign, url, quiz
    this.url,
    this.contentInfo,
  });

  final String id;
  final String name;
  final String type;
  final String? url;
  final String? contentInfo;

  factory MoodleActivity.fromHtml(String id, String name, String type, String? url, {String? contentInfo}) {
    return MoodleActivity(
      id: id,
      name: name,
      type: type,
      url: url,
      contentInfo: contentInfo,
    );
  }
}

class MoodleCourseDetail {
  const MoodleCourseDetail({
    required this.courseId,
    required this.courseName,
    required this.activities,
  });

  final int courseId;
  final String courseName;
  final List<MoodleActivity> activities;
}
