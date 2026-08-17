import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'moodle_api_client.dart';
import '../models/moodle_models.dart';

class MoodleRepository {
  MoodleRepository({required this.apiClient});

  final MoodleApiClient apiClient;

  /// Lấy danh sách khóa học đang theo học
  Future<List<MoodleCourse>> getEnrolledCourses() async {
    final sesskey = apiClient.sesskey;
    if (sesskey != null && sesskey.isNotEmpty) {
      final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_course_get_enrolled_courses_by_timeline_classification';
      final payload = [
        {
          'index': 0,
          'methodname': 'core_course_get_enrolled_courses_by_timeline_classification',
          'args': {
            'offset': 0,
            'limit': 50,
            'classification': 'all',
            'sort': 'fullname',
          },
        }
      ];

      try {
        final resp = await apiClient.dio.post<dynamic>(url, data: payload);
        if (resp.statusCode == 200) {
          dynamic rawData = resp.data;
          if (rawData is String) {
            rawData = jsonDecode(rawData);
          }
          if (rawData is List && rawData.isNotEmpty) {
            final first = rawData.first as Map<String, dynamic>;
            final data = first['data'] as Map<String, dynamic>?;
            final courses = data?['courses'] as List<dynamic>? ?? [];

            if (courses.isNotEmpty) {
              return courses.map((c) => MoodleCourse.fromJson(c as Map<String, dynamic>)).toList();
            }
          }
        }
      } catch (_) {}
    }

    // Fallback: Scraping HTML từ trang /my/
    try {
      final myResp = await apiClient.dio.get<String>('/my/');
      final html = myResp.data ?? '';

      final courseCardsRegex = RegExp(r'<a[^>]+href="https:\/\/courses\.uit\.edu\.vn\/course\/view\.php\?id=(\d+)"[^>]*>(.*?)<\/a>', dotAll: true);
      final matches = courseCardsRegex.allMatches(html);

      final scrapedList = <MoodleCourse>[];
      final seenIds = <int>{};

      for (final match in matches) {
        final idStr = match.group(1);
        final inner = match.group(2) ?? '';
        final id = int.tryParse(idStr ?? '') ?? 0;

        if (id > 0 && !seenIds.contains(id)) {
          seenIds.add(id);
          final cleanName = inner.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (cleanName.isNotEmpty && !cleanName.contains('Chuyển tới nội dung')) {
            scrapedList.add(MoodleCourse(
              id: id,
              fullname: cleanName,
              shortname: cleanName,
              viewUrl: 'https://courses.uit.edu.vn/course/view.php?id=$id',
            ));
          }
        }
      }

      return scrapedList;
    } catch (_) {
      return [];
    }
  }

  /// Lấy danh sách sự kiện / Hạn nộp bài tập (Deadlines)
  Future<List<MoodleDeadline>> getUpcomingDeadlines({int limit = 15}) async {
    final sesskey = apiClient.sesskey;
    if (sesskey == null || sesskey.isEmpty) {
      return [];
    }

    final url = '/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort';
    final payload = [
      {
        'index': 0,
        'methodname': 'core_calendar_get_action_events_by_timesort',
        'args': {
          'timesortfrom': 0,
          'limitnum': limit,
        },
      }
    ];

    try {
      final resp = await apiClient.dio.post<dynamic>(url, data: payload);
      if (resp.statusCode == 200) {
        dynamic rawData = resp.data;
        if (rawData is String) {
          rawData = jsonDecode(rawData);
        }
        if (rawData is List && rawData.isNotEmpty) {
          final first = rawData.first as Map<String, dynamic>;
          final data = first['data'] as Map<String, dynamic>?;
          final events = data?['events'] as List<dynamic>? ?? [];

          return events.map((e) => MoodleDeadline.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Lấy chi tiết tài liệu, slide và hoạt động của một khóa học
  Future<MoodleCourseDetail> getCourseDetail(int courseId, String courseName) async {
    final resp = await apiClient.dio.get<String>('/course/view.php?id=$courseId');
    final html = resp.data ?? '';

    final activities = <MoodleActivity>[];

    final activityRegex = RegExp(r'<li[^>]+class="([^"]*activity[^"]*)"[^>]*id="([^"]*)"[^>]*>(.*?)<\/li>', dotAll: true);
    final matches = activityRegex.allMatches(html);

    for (final match in matches) {
      final classAttr = match.group(1) ?? '';
      final id = match.group(2) ?? 'act_${activities.length}';
      final innerHtml = match.group(3) ?? '';

      final titleMatch = RegExp(r'<span[^>]+class="instancename"[^>]*>(.*?)<\/span>', dotAll: true).firstMatch(innerHtml);
      final rawName = titleMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
      final name = rawName.replaceAll(RegExp(r'\s+(Diễn đàn|Thư mục|URL|Tệp|Bài tập|Trắc nghiệm)$'), '').trim();

      final linkMatch = RegExp(r'<a[^>]+href="([^"]+)"').firstMatch(innerHtml);
      final url = linkMatch?.group(1);

      String type = 'resource';
      if (classAttr.contains('modtype_folder')) {
        type = 'folder';
      } else if (classAttr.contains('modtype_forum')) {
        type = 'forum';
      } else if (classAttr.contains('modtype_assign')) {
        type = 'assign';
      } else if (classAttr.contains('modtype_url')) {
        type = 'url';
      } else if (classAttr.contains('modtype_quiz')) {
        type = 'quiz';
      }

      if (name.isNotEmpty) {
        activities.add(MoodleActivity.fromHtml(id, name, type, url));
      }
    }

    return MoodleCourseDetail(
      courseId: courseId,
      courseName: courseName,
      activities: activities,
    );
  }

  /// Tải trực tiếp tài liệu / slide / file Moodle về máy
  Future<String> downloadActivityFile(MoodleActivity activity, {void Function(int count, int total)? onProgress}) async {
    final activityUrl = activity.url;
    if (activityUrl == null || activityUrl.isEmpty) {
      throw Exception('Hoạt động này không có đường dẫn tải về.');
    }

    // Dùng getExternalStorageDirectory hoặc getTemporaryDirectory/getApplicationDocumentsDirectory
    // Trên Android, getExternalStorageDirectory tương ứng với /storage/emulated/0/Android/data/... (external-path)
    // hoặc getApplicationDocumentsDirectory tương ứng với /data/user/0/.../app_flutter (files-path / root-path)
    Directory dir;
    try {
      final extDir = await getExternalStorageDirectory();
      dir = extDir ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }

    final moodleDir = Directory(p.join(dir.path, 'MoodleDownloads'));
    if (!await moodleDir.exists()) {
      await moodleDir.create(recursive: true);
    }

    // Trường hợp 1: mod/folder -> tải ZIP trọn bộ qua download_folder.php
    if (activity.type == 'folder') {
      final folderIdMatch = RegExp(r'id=(\d+)').firstMatch(activityUrl);
      final folderId = folderIdMatch?.group(1);
      if (folderId != null) {
        final safeName = activity.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetPath = p.join(moodleDir.path, '${safeName}_$folderId.zip');

        await apiClient.dio.download(
          'https://courses.uit.edu.vn/mod/folder/download_folder.php?id=$folderId',
          targetPath,
          onReceiveProgress: onProgress,
          options: Options(
            headers: {
              'Referer': activityUrl,
            },
          ),
        );
        return targetPath;
      }
    }

    // Trường hợp 2: mod/resource -> tải file trực tiếp (PDF/Word/ZIP)
    if (activity.type == 'resource') {
      final viewResp = await apiClient.dio.get<String>(
        activityUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      String? downloadUrl = viewResp.headers.value('location');
      if (downloadUrl == null || downloadUrl.isEmpty) {
        final html = viewResp.data ?? '';
        final match = RegExp(r'href="([^"]*pluginfile\.php[^"]*)"').firstMatch(html);
        downloadUrl = match?.group(1);
      }

      if (downloadUrl == null || downloadUrl.isEmpty) {
        downloadUrl = activityUrl;
      }

      String extension = '.pdf';
      final uriPath = Uri.tryParse(downloadUrl)?.path.toLowerCase() ?? '';
      if (uriPath.endsWith('.pdf')) {
        extension = '.pdf';
      } else if (uriPath.endsWith('.docx') || uriPath.endsWith('.doc')) {
        extension = '.docx';
      } else if (uriPath.endsWith('.zip')) {
        extension = '.zip';
      } else if (uriPath.endsWith('.pptx') || uriPath.endsWith('.ppt')) {
        extension = '.pptx';
      }

      final safeName = activity.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final targetPath = p.join(moodleDir.path, '$safeName$extension');

      await apiClient.dio.download(
        downloadUrl,
        targetPath,
        onReceiveProgress: onProgress,
        options: Options(
          headers: {
            'Referer': activityUrl,
          },
        ),
      );
      return targetPath;
    }

    throw Exception('Loại hoạt động này chưa hỗ trợ tải file trực tiếp.');
  }
}
