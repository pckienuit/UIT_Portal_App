# UIT Portal Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)](https://www.android.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Ứng dụng Android Flutter không chính thức cho sinh viên UIT. Ứng dụng truy cập dữ liệu Portal bằng phiên đăng nhập của chính người dùng và có khu vực cấu hình AI riêng.

> Không liên kết, không được chứng thực, không đại diện cho Trường Đại học Công nghệ Thông tin, ĐHQG-HCM. Tên và nhãn hiệu UIT Portal thuộc chủ sở hữu tương ứng.

## Chức năng

- Đăng nhập Portal và lưu phiên trên thiết bị bằng Android Keystore.
- Thời khóa biểu, bảng điểm, lịch thi, học phí, hồ sơ, thông báo và các dịch vụ sinh viên.
- Trợ lý AI với nhà cung cấp do người dùng tự cấu hình.
- Core AI nội bộ chạy loopback trên `127.0.0.1`, không mở cổng LAN.
- Giao diện sáng/tối, font Be Vietnam Pro, hỗ trợ tiếng Việt.

## Trạng thái phát hành

- Nền tảng: Android.
- Phiên bản đầu tiên: `v1.0.0`.
- APK release dùng chữ ký riêng của maintainer. Chỉ cài APK từ GitHub Releases chính thức hoặc tự build từ mã nguồn.
- Gemini CLI và Antigravity bị tắt trong bản Android công khai. Luồng OAuth desktop của chúng cần client credentials bí mật, không được nhúng vào APK. Dùng nhà cung cấp API key, OAuth được hỗ trợ, 9Router tự host hoặc endpoint OpenAI-compatible thay thế.

## Bắt đầu

### Dùng APK

1. Tải `uit-portal-mobile-v1.0.0.apk` từ [Releases](https://github.com/pckienuit/UIT_Portal_App/releases).
2. Kiểm tra SHA-256 ghi trong release notes.
3. Cài APK trên Android và cho phép cài ứng dụng từ nguồn này khi hệ thống hỏi.

### Build từ mã nguồn

Yêu cầu:

- Flutter `3.44.4`, Dart `3.12.2`
- Android SDK và Android Build Tools
- JDK 17
- Node.js 22 để chạy test embedded router
- Native Node runtime tại `android/app/libnode/`

`android/app/libnode/` là native build input lớn, bị Git ignore và không có trong clone công khai. Clone mới chưa đủ để build APK cho tới khi bạn tự provision runtime tương thích ABI `arm64-v8a` và `x86_64`. Chi tiết release/signing: [docs/RELEASING.md](docs/RELEASING.md).

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew.bat :app:testDebugUnitTest
```

## Bảo mật và dữ liệu

- Không commit cookie, token, mật khẩu, HAR, dữ liệu sinh viên hay keystore.
- Credential AI và phiên Portal nằm trong secure storage của thiết bị.
- Ngữ cảnh Portal chỉ được gửi cho AI khi người dùng chủ động chọn chia sẻ.
- Báo lỗ hổng theo [SECURITY.md](SECURITY.md), không tạo issue công khai.

## Đóng góp

Đọc [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), và [docs/portal_api_inventory.md](docs/portal_api_inventory.md).

## Giấy phép

Mã nguồn gốc của dự án phát hành theo [MIT License](LICENSE). Font Be Vietnam Pro dùng [SIL Open Font License](assets/fonts/OFL.txt). Thư viện và native runtime đi kèm tuân theo giấy phép riêng của từng upstream dependency.

## Hỗ trợ

- Bug và feature: [GitHub Issues](https://github.com/pckienuit/UIT_Portal_App/issues)
- Bảo mật: [SECURITY.md](SECURITY.md)
