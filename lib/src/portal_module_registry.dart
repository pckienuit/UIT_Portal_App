import 'portal_constants.dart';

enum PortalModuleStatus { nativeImplemented, pendingApi }

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
      description: 'Tổng quan phiên đăng nhập và các lối tắt portal.',
      path: '/',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'profile',
      title: 'Thông tin cá nhân',
      description: 'Hồ sơ người học và thông tin tài khoản.',
      path: '/profile',
      status: PortalModuleStatus.pendingApi,
    ),
    PortalModule(
      id: 'services',
      title: 'Dịch vụ',
      description: 'Các dịch vụ trực tuyến của UIT Portal.',
      path: '/services',
      status: PortalModuleStatus.pendingApi,
    ),
    PortalModule(
      id: 'notifications',
      title: 'Thông báo',
      description: 'Thông báo từ portal; nền cho push notification sau này.',
      path: '/notifications',
      status: PortalModuleStatus.pendingApi,
    ),
  ];

  static PortalModule byId(String id) {
    return modules.firstWhere(
      (module) => module.id == id,
      orElse: () => modules.first,
    );
  }
}
