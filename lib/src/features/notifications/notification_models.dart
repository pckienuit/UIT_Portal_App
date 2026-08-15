import '../../portal_constants.dart';

class PortalAnnouncement {
  const PortalAnnouncement({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.publishDate,
    required this.categories,
  });

  final int id;
  final String slug;
  final String title;
  final String excerpt;
  final DateTime? publishDate;
  final List<String> categories;

  Uri? get detailUri {
    if (!RegExp(r'^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$').hasMatch(slug)) {
      return null;
    }
    return Uri.parse('${PortalConstants.portalOrigin}/bai-viet/$slug');
  }

  factory PortalAnnouncement.fromJson(Map<String, dynamic> json) {
    return PortalAnnouncement(
      id: _parseInt(json['id']),
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      publishDate: DateTime.tryParse(json['publish_date']?.toString() ?? ''),
      categories: (json['category_names'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
