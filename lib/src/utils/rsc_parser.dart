import 'dart:convert';
import '../features/profile/profile_model.dart';

class RscParser {
  static StudentProfile? parseStudentProfile(String rscPayload) {
    // The payload contains a JSON string like:
    // "user":{"sub":"...","username":"23520804","displayName":"Kiên Phan Chí","email":"23520804@gm.uit.edu.vn","role":"student"}
    
    final RegExp userRegex = RegExp(r'"user":\s*(\{.*?\})');
    final match = userRegex.firstMatch(rscPayload);
    
    if (match != null && match.groupCount >= 1) {
      try {
        final String userJsonStr = match.group(1)!;
        // Fix potential trailing commas or nested objects that the regex might capture too much of
        // We can just find the first balanced braces.
        final cleanJsonStr = _extractBalancedJson(rscPayload.substring(match.start + '"user":'.length));
        if (cleanJsonStr != null) {
          final Map<String, dynamic> json = jsonDecode(cleanJsonStr);
          return StudentProfile.fromJson(json);
        }
      } catch (e) {
        print('Error parsing student profile JSON: \$e');
      }
    }
    return null;
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
  static List<Map<String, dynamic>> extractObjectsWithKey(String rscPayload, String requiredKey) {
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
          final cleanJsonPart = jsonPart.startsWith('I') ? jsonPart.substring(1) : jsonPart;
          
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
  
  static void _traverseAndFind(dynamic node, String requiredKey, List<Map<String, dynamic>> results) {
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
