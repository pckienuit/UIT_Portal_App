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
}
