class AiProviderValidator {
  AiProviderValidator._();

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String? validateBaseUrl(String value, {required bool debugMode}) {
    final url = normalizeBaseUrl(value);
    if (url.isEmpty) {
      return 'Base URL không được để trống';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'Base URL không hợp lệ';
    }

    if (uri.userInfo.isNotEmpty) {
      return 'Base URL không được chứa thông tin đăng nhập';
    }

    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return 'Base URL không được chứa query parameters hoặc fragments';
    }

    if (uri.scheme != 'https') {
      if (uri.scheme == 'http') {
        if (!debugMode) {
          return 'Base URL bắt buộc sử dụng HTTPS ở chế độ release';
        }

        final host = uri.host.toLowerCase();
        final parts = host.split('.').map(int.tryParse).toList();
        final isPrivateIpv4 =
            parts.length == 4 &&
            parts.every((part) => part != null && part >= 0 && part <= 255) &&
            (parts[0] == 10 ||
                (parts[0] == 192 && parts[1] == 168) ||
                (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31));
        final isLocal = host == 'localhost' || host == '127.0.0.1' || isPrivateIpv4;

        if (!isLocal) {
          return 'HTTP chỉ được phép sử dụng cho localhost hoặc IP mạng LAN ở chế độ debug';
        }
      } else {
        return 'Base URL phải sử dụng HTTPS hoặc HTTP';
      }
    }

    return null;
  }

  static Uri endpoint(String baseUrl, String path) {
    final normalized = normalizeBaseUrl(baseUrl);
    final relative = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalized$relative');
  }
}
