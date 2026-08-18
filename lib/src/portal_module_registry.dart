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
      id: 'tkb',
      title: 'Thời khóa biểu',
      description: 'Lịch học trong tuần, phòng học, giảng viên.',
      path: '/sinh-vien/tkb',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'profile',
      title: 'Thông tin cá nhân',
      description: 'Hồ sơ người học và thông tin tài khoản.',
      path: '/sinh-vien/ho-so',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'moodle_courses',
      title: 'Hạn nộp bài tập Moodle',
      description: 'Theo dõi hạn nộp bài tập, lab và nhắc deadline trên courses.uit.edu.vn.',
      path: '/sinh-vien/moodle-courses',
      status: PortalModuleStatus.nativeImplemented,
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
      id: 'notifications',
      title: 'Thông báo',
      description: 'Thông báo công khai mới nhất từ UIT Portal.',
      path: '/',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'khoa-luan',
      title: 'Khóa luận',
      description: 'Đăng ký đề tài khóa luận.',
      path: '/sinh-vien/khoa-luan',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'tot-nghiep',
      title: 'Tốt nghiệp',
      description: 'Đăng ký xét tốt nghiệp.',
      path: '/sinh-vien/tot-nghiep',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'hoc-bong',
      title: 'Học bổng',
      description: 'Đăng ký xét học bổng.',
      path: '/sinh-vien/hoc-bong',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'ho-tro',
      title: 'Hỗ trợ SV',
      description: 'Hỗ trợ sinh viên.',
      path: '/sinh-vien/ho-tro',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'lich-sinh-hoat',
      title: 'Lịch sinh hoạt',
      description: 'Lịch sinh hoạt, sự kiện ngoại khóa.',
      path: '/sinh-vien/lich-sinh-hoat',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'bao-hiem',
      title: 'Bảo hiểm',
      description: 'Thông tin bảo hiểm y tế.',
      path: '/sinh-vien/bao-hiem',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'hoc-phi',
      title: 'Học phí',
      description: 'Thông tin học phí và công nợ',
      path: '/sinh-vien/hoc-phi',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'gia-han-hoc-phi',
      title: 'Gia hạn học phí',
      description: 'Đăng ký gia hạn đóng học phí.',
      path: '/sinh-vien/gia-han-hoc-phi',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'thoi-hoc-bao-luu',
      title: 'Bảo lưu',
      description: 'Đăng ký thôi học hoặc bảo lưu.',
      path: '/sinh-vien/thoi-hoc-bao-luu',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'lich-thi',
      title: 'Lịch thi',
      description: 'Xem lịch thi các học kỳ.',
      path: '/sinh-vien/lich-thi',
      status: PortalModuleStatus.nativeImplemented,
    ),
    PortalModule(
      id: 'khao-sat-giang-day',
      title: 'Khảo sát',
      description: 'Thực hiện khảo sát đánh giá giảng dạy.',
      path: '/sinh-vien/khao-sat-giang-day',
      status: PortalModuleStatus.nativeImplemented,
    ),
  ];

  static PortalModule byId(String id) {
    return modules.firstWhere(
      (module) => module.id == id,
      orElse: () => modules.firstWhere((module) => module.id == 'dashboard'),
    );
  }
}
