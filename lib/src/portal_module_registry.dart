import 'portal_constants.dart';

enum PortalModuleStatus { nativePlanned, webFallback }

class PortalModule {
  const PortalModule({
    required this.id,
    required this.title,
    required this.description,
    required this.path,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final String path;
  final PortalModuleStatus status;

  Uri get webUri => Uri.parse('${PortalConstants.portalOrigin}$path');
}

class PortalModuleRegistry {
  const PortalModuleRegistry._();

  static const List<PortalModule> modules = [
    PortalModule(
      id: 'dashboard',
      title: 'Trang chủ',
      description: 'Điểm vào portal sau khi đăng nhập SSO.',
      path: '/',
      status: PortalModuleStatus.webFallback,
    ),
    PortalModule(
      id: 'profile',
      title: 'Thông tin cá nhân',
      description: 'Hồ sơ người học và thông tin tài khoản.',
      path: '/profile',
      status: PortalModuleStatus.webFallback,
    ),
    PortalModule(
      id: 'services',
      title: 'Dịch vụ',
      description: 'Các dịch vụ trực tuyến của UIT Portal.',
      path: '/services',
      status: PortalModuleStatus.webFallback,
    ),
    PortalModule(
      id: 'notifications',
      title: 'Thông báo',
      description: 'Thông báo từ portal; sẽ là nền cho push notification.',
      path: '/notifications',
      status: PortalModuleStatus.webFallback,
    ),
  ];

  static PortalModule byId(String id) {
    return modules.firstWhere(
      (module) => module.id == id,
      orElse: () => modules.first,
    );
  }
}
