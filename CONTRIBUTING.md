# Contributing

Cảm ơn đóng góp cho UIT Portal Mobile.

## Trước khi mở issue hoặc PR

- Không gửi cookie, token, mật khẩu, MSSV, email, ảnh dữ liệu cá nhân, HAR, keystore hoặc log chưa redaction.
- API Portal là nội bộ và có thể đổi bất kỳ lúc nào. Chỉ ghi dữ liệu đã sanitize vào `docs/portal_api_inventory.md`.
- Không thêm WebView fallback để lách một module native chưa hoàn thành.
- Không thêm OAuth client secret vào Kotlin, Dart, asset, GitHub Actions hay Gradle.

## Môi trường

Xem yêu cầu tại [README.md](README.md). `android/app/libnode/` là native build input local, không được commit.

## Quy trình

1. Fork, tạo branch rõ mục đích: `fix/...`, `feat/...`, `docs/...`.
2. Viết test thất bại trước khi sửa production code.
3. Chạy các kiểm tra liên quan:

   ```bash
   flutter analyze
   flutter test
   cd android && ./gradlew.bat :app:testDebugUnitTest
   ```

4. Với thay đổi Android/Flutter UI, build APK mới và kiểm tra light mode, dark mode, font scale, overflow trên emulator hoặc thiết bị.
5. Mở PR nêu rõ: mục tiêu, thay đổi, kiểm thử, rủi ro, screenshot nếu có UI.

## Quy ước

- Dart: `dart format` chỉ trên file bạn sở hữu trong PR.
- Kotlin: giữ style hiện có, không format cả repo.
- UI copy: tiếng Việt trực tiếp, không dùng dữ liệu mock trong production.
- Provider catalog: thay đổi phải có lý do audit và test catalog tương ứng.

## Commit

Dùng Conventional Commits:

```text
feat(schedule): add exam calendar empty state
fix(auth): reject invalid callback state
docs: add Android release guide
```

## Cần hỗ trợ

Tạo issue với template phù hợp. Lỗ hổng bảo mật phải theo [SECURITY.md](SECURITY.md), không đăng public issue.
