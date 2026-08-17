import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class QrImageSaver {
  const QrImageSaver._();

  static const MethodChannel _mediaChannel =
      MethodChannel('com.pckienuit.uitportal/media_saver');

  /// Lưu ảnh QR (chuỗi base64) vào Album/Thư viện ảnh của máy thật (Android MediaStore / iOS Photos)
  static Future<String> saveQrCode(
    String qrRaw, {
    String prefix = 'QR_UIT_Portal',
  }) async {
    final cleanBase64 =
        qrRaw.startsWith('data:') ? qrRaw.split(',').last : qrRaw;
    final bytes = base64Decode(cleanBase64);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${prefix}_$timestamp.png';

    if (Platform.isAndroid) {
      try {
        final result = await _mediaChannel.invokeMethod<String>(
          'saveImageToGallery',
          {'bytes': bytes, 'filename': filename},
        );
        if (result != null && result.isNotEmpty) {
          return result;
        }
      } catch (_) {
        // Fallback to direct file system if channel fails
      }
    }

    // Fallback file system (Documents / App Storage)
    final targetDir = await getApplicationDocumentsDirectory();
    final filePath = '${targetDir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return filePath;
  }
}
