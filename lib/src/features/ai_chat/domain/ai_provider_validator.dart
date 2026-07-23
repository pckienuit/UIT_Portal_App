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
        final isLocal =
            host != '10.0.2.2' &&
            (host == 'localhost' ||
                host == '127.0.0.1' ||
                host.startsWith('192.168.') ||
                host.startsWith('10.') ||
                host.startsWith('172.'));

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
