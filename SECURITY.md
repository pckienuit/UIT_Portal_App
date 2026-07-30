# Security Policy

## Phiên bản hỗ trợ

| Version | Supported |
| --- | --- |
| `1.0.x` | Yes |
| `< 1.0.0` | No |

## Báo lỗ hổng

Không mở public issue cho lỗ hổng liên quan credential, Portal session, OAuth, local router hoặc dữ liệu sinh viên.

1. Dùng GitHub private security advisory nếu khả dụng: <https://github.com/pckienuit/UIT_Portal_App/security/advisories/new>
2. Hoặc email `23520804@gm.uit.edu.vn` với tiêu đề `[SECURITY] UIT Portal Mobile`.
3. Mô tả phạm vi, bước tái hiện, tác động, phiên bản và bằng chứng đã redaction.

Xác nhận tiếp nhận mục tiêu trong 7 ngày. Không công bố chi tiết trước khi có bản vá hoặc thống nhất disclosure date.

## Quy tắc bắt buộc

- Không đưa OAuth client secret vào APK hoặc repository. Native app là public client. PKCE không biến secret nhúng thành an toàn.
- Không gửi cookie Portal, access token, refresh token, API key, password, HAR hay thông tin sinh viên vào issue/PR/log.
- Core AI nội bộ chỉ bind loopback `127.0.0.1` hoặc `::1`.
- API endpoint phải dùng HTTPS trừ loopback runtime được kiểm soát.
- Release keystore và `android/key.properties` luôn local, Git ignored.

## Lịch sử credential

Một secret đã từng xuất hiện trong Git history phải được revoke/rotate tại provider console. Xóa khỏi source hoặc tag mới không thu hồi bản sao đã bị tải xuống. Không phát hành OAuth provider đó trong APK cho tới khi quy trình public-client được xác nhận.
