import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/notifications/notification_models.dart';

void main() {
  test('parses verified public announcement payload', () {
    final announcement = PortalAnnouncement.fromJson({
      'id': 7,
      'title': 'Thông báo mới',
      'excerpt': 'Nội dung tóm tắt',
      'category_names': ['Sinh viên'],
      'publish_date': '2026-08-15T01:02:03.000Z',
    });

    expect(announcement.id, 7);
    expect(announcement.title, 'Thông báo mới');
    expect(announcement.categories, ['Sinh viên']);
    expect(announcement.publishDate?.toUtc().year, 2026);
  });

  test('builds official detail URI from a safe announcement slug', () {
    final announcement = PortalAnnouncement.fromJson({
      'id': 7,
      'title': 'Thông báo mới',
      'slug': 'thong-bao-moi',
      'excerpt': '',
      'category_names': const [],
    });

    expect(
      announcement.detailUri,
      Uri.parse('https://portal.uit.edu.vn/bai-viet/thong-bao-moi'),
    );
  });

  test('builds detail URI from verified mixed-case live slug', () {
    final announcement = PortalAnnouncement.fromJson({
      'id': 7,
      'title': 'Khảo sát',
      'slug': 'IR3-2026',
      'excerpt': '',
      'category_names': const [],
    });

    expect(
      announcement.detailUri,
      Uri.parse('https://portal.uit.edu.vn/bai-viet/IR3-2026'),
    );
  });

  test('does not build a detail URI from malformed remote slug', () {
    final announcement = PortalAnnouncement.fromJson({
      'id': 7,
      'title': 'Thông báo mới',
      'slug': '../admin',
      'excerpt': '',
      'category_names': const [],
    });

    expect(announcement.detailUri, isNull);
  });
}
