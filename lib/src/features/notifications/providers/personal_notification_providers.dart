import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/widget_preferences_provider.dart';
import '../data/personal_notification_repository.dart';
import '../models/personal_notification_item.dart';
import '../../schedule/schedule_model.dart';
import '../../parking_registration/parking_registration_model.dart';
import '../../grades/grades_model.dart';
import '../../tuition/tuition_model.dart';

final personalNotificationRepositoryProvider = Provider<PersonalNotificationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersonalNotificationRepository(prefs);
});

class PersonalNotificationController extends Notifier<List<PersonalNotificationItem>> {
  @override
  List<PersonalNotificationItem> build() {
    final repo = ref.watch(personalNotificationRepositoryProvider);
    return repo.getNotifications();
  }

  Future<void> addNotification(PersonalNotificationItem item) async {
    final repo = ref.read(personalNotificationRepositoryProvider);
    await repo.addNotification(item);
    state = repo.getNotifications();
  }

  Future<void> markAsRead(String id) async {
    final repo = ref.read(personalNotificationRepositoryProvider);
    await repo.markAsRead(id);
    state = repo.getNotifications();
  }

  Future<void> markAllAsRead() async {
    final repo = ref.read(personalNotificationRepositoryProvider);
    await repo.markAllAsRead();
    state = repo.getNotifications();
  }

  Future<void> deleteNotification(String id) async {
    final repo = ref.read(personalNotificationRepositoryProvider);
    await repo.deleteNotification(id);
    state = repo.getNotifications();
  }

  Future<void> clearAll() async {
    final repo = ref.read(personalNotificationRepositoryProvider);
    await repo.clearAll();
    state = [];
  }

  /// Tự động quét TKB để tạo thông báo nhắc lịch học hôm nay
  Future<void> syncScheduleAlerts(ScheduleResponse? schedule) async {
    if (schedule == null || schedule.tiets.isEmpty) return;

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final todayClasses = schedule.tiets.where((t) => t.ngay == todayStr).toList();

    if (todayClasses.isEmpty) return;

    final classSummary = todayClasses.map((c) => '${c.tenMonHoc} (${c.phong}, Tiết ${c.tietBatDau})').join(', ');
    final alertId = 'schedule_alert_$todayStr';

    final alert = PersonalNotificationItem(
      id: alertId,
      title: 'Lịch học hôm nay (${todayClasses.length} môn)',
      body: classSummary,
      timestamp: now,
      type: PersonalNotificationType.schedule,
      targetRoute: '/schedule',
    );

    await addNotification(alert);
  }

  /// Tự động quét Đăng ký gửi xe để tạo cảnh báo hết hạn
  Future<void> syncParkingAlerts(ParkingRegistrationResponse? parking) async {
    if (parking == null || parking.records.isEmpty) return;

    final now = DateTime.now();

    for (final record in parking.records) {
      if (record.effectiveDate == null) continue;
      final expiryDate = DateTime.tryParse(record.effectiveDate!);
      if (expiryDate == null) continue;

      final diffDays = expiryDate.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (diffDays <= 3 && diffDays >= 0) {
        final alertId = 'parking_expiry_${record.licensePlateNumber}_${record.effectiveDate}';
        final alert = PersonalNotificationItem(
          id: alertId,
          title: diffDays == 0 ? 'Vé xe hết hạn hôm nay!' : 'Vé xe sắp hết hạn (còn $diffDays ngày)',
          body: 'Xe ${record.licensePlateNumber ?? ''} sẽ hết hạn vào ngày ${record.effectiveDate}. Chạm để gia hạn ngay.',
          timestamp: now,
          type: PersonalNotificationType.parking,
          targetRoute: '/module/parking_registration',
        );
        await addNotification(alert);
      }
    }
  }

  /// Tự động quét Điểm mới
  Future<void> syncGradesAlerts(GradesResponse? grades) async {
    if (grades == null || grades.semesterGroups.isEmpty) return;

    final latestSemester = grades.semesterGroups.first;
    for (final subject in latestSemester.subjects) {
      if (subject.subjectName.isNotEmpty && (subject.coursePoint.isNotEmpty || subject.finalPoint.isNotEmpty)) {
        final scoreText = subject.coursePoint.isNotEmpty ? subject.coursePoint : subject.finalPoint;
        final alertId = 'grade_alert_${subject.subjectCode}_$scoreText';
        final alert = PersonalNotificationItem(
          id: alertId,
          title: 'Điểm mới: ${subject.subjectName}',
          body: 'Môn ${subject.subjectName} (${subject.subjectCode}) đã có kết quả: $scoreText',
          timestamp: DateTime.now(),
          type: PersonalNotificationType.grades,
          targetRoute: '/module/grades',
        );
        await addNotification(alert);
      }
    }
  }

  /// Tự động quét Học phí mới / Công nợ
  Future<void> syncTuitionAlerts(List<TuitionRecord>? tuitionList) async {
    if (tuitionList == null || tuitionList.isEmpty) return;

    for (final record in tuitionList) {
      if (record.amountDue > 0) {
        final alertId = 'tuition_alert_${record.id ?? record.period}_${record.amountDue}';
        final alert = PersonalNotificationItem(
          id: alertId,
          title: 'Nhắc nhở học phí ${record.semesterLabel} (${record.yearName})',
          body: 'Bạn có khoản học phí cần thanh toán: ${record.amountDue} đ. Chạm để quét mã QR.',
          timestamp: DateTime.now(),
          type: PersonalNotificationType.tuition,
          targetRoute: '/module/hoc-phi',
        );
        await addNotification(alert);
      }
    }
  }
}

final personalNotificationProvider =
    NotifierProvider<PersonalNotificationController, List<PersonalNotificationItem>>(
  PersonalNotificationController.new,
);
