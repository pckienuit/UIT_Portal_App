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
      id: 'confirmation_paper',
      title: 'Giấy xác nhận',
      description: 'Đăng ký cấp các loại giấy xác nhận.',
      path: '/sinh-vien/giay-xac-nhan',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'certificate_validation',
      title: 'Xác nhận chứng chỉ',
      description: 'Nộp và xác nhận chứng chỉ ngoại ngữ, tin học.',
      path: '/sinh-vien/xac-nhan-chung-chi',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'student_card',
      title: 'Thẻ sinh viên',
      description: 'Thông tin thẻ sinh viên điện tử.',
      path: '/sinh-vien/the-sinh-vien',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'parking_registration',
      title: 'Đăng ký gửi xe',
      description: 'Đăng ký và gia hạn vé gửi xe tháng.',
      path: '/sinh-vien/gui-xe',
      status: PortalModuleStatus.nativeImplemented,
    ),

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
      path: '/sinh-vien/ho-so',
      status: PortalModuleStatus.pendingApi,
    ),
    PortalModule(
      id: 'grades',
      title: 'Bảng điểm',
      description: 'Kết quả học tập, điểm quá trình, điểm thi.',
      path: '/sinh-vien/bang-diem',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'training_point',
      title: 'Điểm rèn luyện',
      description: 'Kết quả điểm rèn luyện và xếp loại.',
      path: '/sinh-vien/diem-ren-luyen',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'transcript_request',
      title: 'Xin bảng điểm',
      description: 'Đăng ký xin cấp bảng điểm.',
      path: '/sinh-vien/xin-bang-diem',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'exam_postponement',
      title: 'Hoãn thi & Thi lại',
      description: 'Đăng ký hoãn thi và xem lịch sử.',
      path: '/sinh-vien/hoan-thi',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'revaluation',
      title: 'Phúc khảo điểm',
      description: 'Đăng ký phúc khảo và xem lịch sử.',
      path: '/sinh-vien/phuc-khao',
      status: PortalModuleStatus.nativeImplemented,
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
