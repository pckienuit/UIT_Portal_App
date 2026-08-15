import 'package:flutter/services.dart';

const _channel = MethodChannel('com.pckienuit.uitportal/external_url');

Future<void> openPortalArticle(Uri uri) {
  if (!_isPortalArticle(uri)) {
    throw ArgumentError.value(uri, 'uri', 'URL bài viết UIT không hợp lệ');
  }
  return _channel.invokeMethod<void>('openPortalArticle', {
    'url': uri.toString(),
  });
}

bool _isPortalArticle(Uri uri) {
  return uri.scheme == 'https' &&
      uri.host == 'portal.uit.edu.vn' &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'bai-viet' &&
      RegExp(
        r'^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$',
      ).hasMatch(uri.pathSegments.last);
}
