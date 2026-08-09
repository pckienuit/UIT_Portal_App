# Xác minh live session Portal

Tài liệu này chạy khi `https://portal.uit.edu.vn/api/auth/login` trả HTTP response trở lại. Không commit password, cookie, access token, refresh token, HAR chưa sanitize hoặc ảnh màn hình có dữ liệu sinh viên.

## Điều kiện trước

- APK debug/release mới có patch session lifecycle.
- Android thật hoặc emulator có mạng.
- Portal và SSO trả response bình thường.
- Một account thử nghiệm được phép dùng.

## Mục tiêu

Xác nhận hợp đồng server thật cho ba nhánh:

1. Login cookie được persist và sống qua app restart.
2. Cookie hết hạn khiến app local logout và về `/login`.
3. OAuth mobile client, nếu UIT cấp, refresh access token đúng cách.

## 1. Kiểm tra Portal hồi phục

Từ máy phát triển, không gửi credential:

```bash
curl -4 -sS -D - -o NUL --connect-timeout 15 --max-time 30 \
  'https://portal.uit.edu.vn/api/auth/login'
```

Kỳ vọng:

- Có HTTP status, thường `302`.
- Header `Location` dẫn tới `sso.uit.edu.vn`.
- Có `Set-Cookie` nếu Portal cần khởi tạo OIDC flow.

Nếu TLS xong nhưng không có HTTP byte trước timeout, Portal/upstream vẫn lỗi. Dừng kiểm tra, không kết luận patch lỗi.

## 2. Login và persistence

1. Cài APK mới.
2. Login bằng form native.
3. Mở Hồ sơ, Thời khóa biểu và một module POST như Học phí.
4. Force-stop app bằng Android Settings hoặc `adb shell am force-stop com.pckienuit.uitportal`.
5. Mở lại app.
6. Mở lại ba module trên.

Kỳ vọng:

- App vào màn hình chính, không quay lại login trước request đầu.
- Request authenticated thành công khi cookie Portal còn hiệu lực.
- Không log raw `Cookie=`, password hay response hồ sơ.

Ghi lại đã sanitize:

```text
build SHA-256:
platform / Android version:
login time UTC:
restart time UTC:
profile result: pass/fail + HTTP status only
schedule result: pass/fail + HTTP status only
tuition result: pass/fail + HTTP status only
```

## 3. Server báo cookie expired

Cần làm session Portal hiện có trở nên invalid. Chỉ dùng một trong các cách được phép:

- Chờ server TTL thật.
- Logout phiên đó từ web Portal/SSO nếu UIT hỗ trợ.
- Cài APK khác sạch app data, rồi kiểm tra cookie cũ không bị reuse.

Không thêm debug endpoint, không sửa secure storage production, không lưu cookie vào test source.

Sau khi cookie invalid:

1. Mở app đang có phiên cũ.
2. Mở một module gọi Portal.
3. Theo dõi UI và log sanitize.

Kỳ vọng:

- Response `401`, `403`, redirect login/SSO, hoặc Keycloak login form được phân loại là expired.
- App xóa local secure storage session.
- Router chuyển về `/login` ngay.
- Retry module không gửi credential/session cũ.

Không được coi HTML module hợp lệ là expired. Kiểm tra một trang HTML Portal hợp lệ trước và sau test để phát hiện false positive.

## 4. OAuth refresh, chỉ khi UIT cấp mobile client

Không chạy phần này với credential form scrape. Nó chỉ áp dụng nếu config có OAuth mobile client hợp lệ, access token expiry, và refresh token.

1. Login qua OAuth mobile client.
2. Chờ access token gần hết hạn hoặc dùng môi trường UIT được phép cấp token TTL ngắn.
3. Background rồi resume app, hoặc gọi module Portal.
4. Kiểm tra result không chứa secret.

Kỳ vọng:

- Một `TokenRequest(refreshToken: ...)` refresh access token.
- Module hoàn thành mà không yêu cầu login lại.
- Refresh token mới, nếu server trả về, thay token cũ trong secure storage.
- Nhiều request song song chỉ tạo một refresh attempt.

Nếu refresh token bị từ chối:

- App xóa local session.
- App chuyển `/login`.
- Không loop refresh và không remote logout chặn UI.

## 5. Bằng chứng cần đính kèm vào issue/PR nội bộ

- SHA-256 APK.
- Android version, network loại, UTC timestamp.
- HTTP status/redirect host đã sanitize.
- Kết quả từng mục: pass/fail.
- Logcat đã redact, không có password/cookie/token/MSSV/dữ liệu học tập.

## Automated coverage đã có

```bash
flutter test test/auth_controller_test.dart \
  test/portal_api_client_test.dart \
  test/auth_session_redirect_test.dart
flutter test
flutter analyze
flutter build apk --debug
```

Các test này chứng minh state machine, expiry detector và notification contract. Chúng không thay thế live server-contract test ở trên.

## Ghi nhận blocker hiện tại

Ngày 2026-08-09 từ môi trường phát triển:

```text
portal.uit.edu.vn:443 TCP connected
TLS handshake completed
/api/auth/login returned no HTTP byte after 25–60 seconds
```

Google HTTPS và mạng trực tiếp hoạt động; không có WinHTTP proxy. Đây là lỗi/hết phản hồi ở Portal hoặc upstream của Portal, không phải bằng chứng credential hay app patch lỗi.
