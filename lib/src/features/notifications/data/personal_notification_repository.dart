import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/personal_notification_item.dart';

class PersonalNotificationRepository {
  PersonalNotificationRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'uit_portal_personal_notifications';

  List<PersonalNotificationItem> getNotifications() {
    final rawJson = _prefs.getString(_storageKey);
    if (rawJson == null || rawJson.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => PersonalNotificationItem.fromJson(e))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifications(List<PersonalNotificationItem> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  Future<void> addNotification(PersonalNotificationItem item) async {
    final current = getNotifications();
    // Tránh thêm trùng ID
    if (current.any((e) => e.id == item.id)) {
      return;
    }
    current.insert(0, item);
    // Giới hạn lưu tối đa 100 thông báo gần nhất
    if (current.length > 100) {
      current.removeRange(100, current.length);
    }
    await saveNotifications(current);
  }

  Future<void> markAsRead(String id) async {
    final current = getNotifications();
    final updated = current.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
    await saveNotifications(updated);
  }

  Future<void> markAllAsRead() async {
    final current = getNotifications();
    final updated = current.map((item) => item.copyWith(isRead: true)).toList();
    await saveNotifications(updated);
  }

  Future<void> deleteNotification(String id) async {
    final current = getNotifications();
    current.removeWhere((item) => item.id == id);
    await saveNotifications(current);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
  }
}
