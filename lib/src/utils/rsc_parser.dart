import 'dart:convert';
import '../features/profile/profile_model.dart';

class RscParser {
  static StudentProfile? parseStudentProfile(String rscPayload) {
    return parseFullProfile(rscPayload);
  }

  static StudentProfile? parseFullProfile(String rscPayload) {
    try {
      // 1. Tìm object "profile" chi tiết (tránh dùng split hay regex quá lớn để không treo máy)
      final int profileIdx = rscPayload.indexOf('"profile":{');
      Map<String, dynamic>? profileJson;
      if (profileIdx != -1) {
        final String? cleanProfileJson = _extractBalancedJson(
          rscPayload.substring(profileIdx + '"profile":'.length),
        );
        if (cleanProfileJson != null) {
          profileJson = jsonDecode(cleanProfileJson);
        }
      }

      // 2. Tìm thông tin session user (từ đối tượng user nhỏ)
      final RegExp userRegex = RegExp(r'"user":\s*(\{.*?\})');
      final match = userRegex.firstMatch(rscPayload);
      Map<String, dynamic>? sessionJson;
      if (match != null && match.groupCount >= 1) {
        final cleanSessionJson = _extractBalancedJson(
          rscPayload.substring(match.start + '"user":'.length),
        );
        if (cleanSessionJson != null) {
          sessionJson = jsonDecode(cleanSessionJson);
        }
      }

      if (profileJson == null && sessionJson == null) return null;

      // 3. Tìm thông tin học thuật (Nằm rải rác trong các span của Next.js VDOM)
      String? cohort;
      String? className;
      String? major;

      // Regex tìm "Khóa 2023"
      final cohortMatch = RegExp(
        r'"children":"(Khóa \d+)"',
      ).firstMatch(rscPayload);
      if (cohortMatch != null) cohort = cohortMatch.group(1);

      // Regex tìm tên lớp (vd: KTMT2023.1, HTTT2022.2)
      final classMatch = RegExp(
        r'"children":"([A-Z]{2,6}\d{4}\.\d+)"',
      ).firstMatch(rscPayload);
      if (classMatch != null) className = classMatch.group(1);

      // Regex tìm ngành học (vd: D520214 - Kỹ thuật Máy tính)
      final majorMatch = RegExp(
        r'"children":"([A-Z0-9]+ - [^"]+)"',
      ).firstMatch(rscPayload);
      if (majorMatch != null) major = majorMatch.group(1);

      final academic = AcademicInfo(
        cohort: cohort,
        className: className,
        major: major,
      );

      return StudentProfile.fromJson(
        profileJson ?? {},
        sessionUser: sessionJson,
        academic: academic,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractBalancedJson(String text) {
    int balance = 0;
    bool inString = false;
    bool escapeNext = false;
    int startIndex = text.indexOf('{');
    if (startIndex == -1) return null;

    for (int i = startIndex; i < text.length; i++) {
      final char = text[i];
      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
      }

      if (!inString) {
        if (char == '{') {
          balance++;
        } else if (char == '}') {
          balance--;
          if (balance == 0) {
            return text.substring(startIndex, i + 1);
          }
        }
      }
    }
    return null;
  }

  /// Trích xuất danh sách các đối tượng JSON từ chuỗi RSC dựa vào một trường đặc trưng (keyword).
  /// Ví dụ: keyword = 'tenMonHoc' hoặc 'phongHoc'
  static List<Map<String, dynamic>> extractObjectsWithKey(
    String rscPayload,
    String requiredKey,
  ) {
    final results = <Map<String, dynamic>>[];

    // RSC payload chia thành các dòng
    final lines = rscPayload.split('\n');
    for (final line in lines) {
      if (!line.contains(requiredKey)) continue;

      try {
        // Các dòng RSC thường bắt đầu bằng id:[...] hoặc id:I[...] hoặc id:{...}
        // Ta tìm vị trí bắt đầu của cấu trúc JSON hợp lệ gần nhất
        int startIndex = line.indexOf(':[');
        if (startIndex == -1) startIndex = line.indexOf(':{');
        if (startIndex == -1) startIndex = line.indexOf(':I[');

        if (startIndex != -1) {
          // Cắt bỏ phần prefix `id:`
          final jsonPart = line.substring(line.indexOf(':', startIndex) + 1);
          // Xóa chữ I nếu có (id:I[...])
          final cleanJsonPart = jsonPart.startsWith('I')
              ? jsonPart.substring(1)
              : jsonPart;

          final decoded = jsonDecode(cleanJsonPart);
          _traverseAndFind(decoded, requiredKey, results);
        }
      } catch (e) {
        // Bỏ qua nếu dòng này không parse được
      }
    }

    // Loại bỏ các đối tượng trùng lặp (dựa trên việc so sánh nội dung chuỗi JSON)
    final uniqueResults = <String, Map<String, dynamic>>{};
    for (final item in results) {
      uniqueResults[jsonEncode(item)] = item;
    }

    return uniqueResults.values.toList();
  }

  static void _traverseAndFind(
    dynamic node,
    String requiredKey,
    List<Map<String, dynamic>> results,
  ) {
    if (node is Map<String, dynamic>) {
      bool hasMatch = node.containsKey(requiredKey);
      if (!hasMatch) {
        for (final value in node.values) {
          if (value?.toString().contains(requiredKey) == true) {
            hasMatch = true;
            break;
          }
        }
      }

      if (hasMatch) {
        results.add(node);
      }
      for (final value in node.values) {
        _traverseAndFind(value, requiredKey, results);
      }
    } else if (node is List) {
      for (final item in node) {
        _traverseAndFind(item, requiredKey, results);
      }
    }
  }
}
