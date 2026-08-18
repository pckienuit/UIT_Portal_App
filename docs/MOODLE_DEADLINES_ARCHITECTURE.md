# UIT Portal Mobile — Moodle Deadlines & Dual-Auth Architecture

Tài liệu kỹ thuật giải thích chi tiết cơ chế xác thực kép (Dual-Authentication Pipeline), thu thập dữ liệu lịch trình (Calendar/Events), phân loại trạng thái nộp bài tập và đồng bộ thông tin Deadline từ hệ thống Moodle (`courses.uit.edu.vn`) vào ứng dụng UIT Portal Mobile.

---

## 1. Tổng quan Kiến trúc Xác thực (Dual-Auth Pipeline)

Hệ thống của Trường Đại học Công nghệ Thông tin (UIT) sử dụng hai nền tảng độc lập về cơ chế quản lý phiên (Session Realm):
* **UIT Portal (`portal.uit.edu.vn`):** Sử dụng hệ thống Single Sign-On dựa trên chuẩn **OpenID Connect (OIDC / Keycloak)** tại máy chủ `auth.uit.edu.vn`.
* **UIT Courses (`courses.uit.edu.vn`):** Sử dụng nền tảng **Moodle LMS truyền thống**, quản lý phiên thông qua Cookie **`MoodleSession`** và CSRF token **`logintoken` / `sesskey`**.

```
                           ┌── [Luồng 1] ──► Keycloak OIDC (auth.uit.edu.vn) ──► PortalSession Cookie / REST Tokens
[ MSSV + Mật khẩu duy nhất ]
                           └── [Luồng 2] ──► Moodle Form (courses.uit.edu.vn) ──► MoodleSession Cookie + Sesskey
```

### Quy trình Xác thực Moodle ngầm (`MoodleApiClient`):
1. **Bước 1 — Trích xuất `logintoken` động:**
   * Gửi request `GET https://courses.uit.edu.vn/login/index.php`.
   * Sử dụng Regular Expression trích xuất giá trị token CSRF từ input ẩn:
     ```html
     <input type="hidden" name="logintoken" value="[LOGINTOKEN_DONG]" />
     ```
2. **Bước 2 — Gửi thông tin đăng nhập URL-encoded:**
   * Gửi request `POST https://courses.uit.edu.vn/login/index.php` với Content-Type `application/x-www-form-urlencoded`.
   * **Bắt buộc đính kèm Header mạng:**
     * `Origin: https://courses.uit.edu.vn`
     * `Referer: https://courses.uit.edu.vn/login/index.php`
   * Payload gửi đi:
     ```json
     {
       "anchor": "",
       "logintoken": "[LOGINTOKEN_DONG]",
       "username": "23520804",
       "password": "[MAT_KHAU]"
     }
     ```
3. **Bước 3 — Xử lý chuỗi Redirect `303 See Other` & Chụp Cookie:**
   * Moodle phản hồi mã `303 See Other` và cấp một Cookie `MoodleSession` mới trong Header `Set-Cookie`.
   * HTTP Client tắt auto-redirect (`followRedirects = false`), bắt trọn vẹn `Set-Cookie: MoodleSession=...` và `MOODLEID1_`, lưu vào `_cookieJar` nội bộ rồi mới thực hiện `GET` thủ công theo Header `Location` (chuỗi `303` -> `303` -> `200`).
4. **Bước 4 — Bỏ qua lỗi SSL Handshake trên Android Native:**
   * Cấu hình `IOHttpClientAdapter` với `badCertificateCallback` cho host `*.uit.edu.vn` nhằm khắc phục lỗi `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate` do Android chặn chuỗi Certificate Authority (CA) trung gian của trường.
5. **Bước 5 — Trích xuất `sesskey` & Lưu trữ bảo mật:**
   * Trích xuất chuỗi `sesskey` từ HTML phản hồi bằng regex: `r'"sesskey":"([^"]+)"'`.
   * Lưu trữ `MoodleSession` và `sesskey` vào `FlutterSecureStorage` (được bọc trong khối `try-catch` an toàn).

---

## 2. Cơ chế Thu thập Dữ liệu Hạn nộp bài tập (Deadlines Extraction)

Sau khi có `MoodleSession` và `sesskey`, `MoodleRepository` sử dụng **cơ chế kết hợp kép (Hybrid Extraction Pipeline)** để lấy trọn vẹn 100% dữ liệu bài tập:

```
                  ┌──► Moodle AJAX Calendar Service (Lấy bài sắp tới & quá hạn)
[ MoodleRepository ]
                  └──► Recent Courses Deep Scanner (Quét trạng thái bài đã nộp)
```

### 2.1. Khai thác Endpoint Lịch Moodle (`core_calendar_get_action_events_by_timesort`)
* **Endpoint:** `POST https://courses.uit.edu.vn/lib/ajax/service.php?sesskey=[SESSKEY]&info=core_calendar_get_action_events_by_timesort`
* **Quy định API Moodle:** Tham số `limitnum` bị giới hạn nghiêm ngặt từ `1` đến `50` (nếu vượt quá 50, server sẽ trả về lỗi `error/Limit must be between 1 and 50`).
* **Kỹ thuật Multi-Window Payload:** Gửi đồng thời 2 mốc thời gian trong cùng một mảng request để thu thập đầy đủ:
  ```json
  [
    {
      "index": 0,
      "methodname": "core_calendar_get_action_events_by_timesort",
      "args": {
        "timesortfrom": 1786981343,   // Thời điểm hiện tại -> Lấy bài sắp tới hạn
        "limitnum": 50
      }
    },
    {
      "index": 1,
      "methodname": "core_calendar_get_action_events_by_timesort",
      "args": {
        "timesortfrom": 1771429343,   // 180 ngày trước -> Lấy bài trong học kỳ
        "limitnum": 50
      }
    }
  ]
  ```
* **Dữ liệu trích xuất từ mỗi Event:**
  * `id`: ID sự kiện lịch.
  * `name`: Tên bài tập (được làm sạch, cắt bỏ hậu tố `" tới hạn"` hoặc `" is due"`).
  * `course.fullname`: Tên đầy đủ môn học (ví dụ: *Logic mờ cho ứng dụng hệ thống nhúng - CE320.Q21*).
  * `course.shortname`: Mã môn/Mã lớp (ví dụ: *CE320.Q21*).
  * `timesort`: Mốc thời gian Unix Timestamp hạn nộp.
  * `url`: Đường dẫn trang nộp bài tập (`https://courses.uit.edu.vn/mod/assign/view.php?id=...`).

### 2.2. Cơ chế Quét bài tập đã nộp (`Recent Courses Deep Scanner`)
Các sự kiện lịch sau khi sinh viên đã nộp bài có thể bị ẩn khỏi timeline chính. Để hiển thị chính xác mục **"Đã hoàn thành"**, `MoodleRepository` thực hiện:
1. Gọi `core_course_get_enrolled_courses_by_timeline_classification` để lấy danh sách các khóa học đang tham gia.
2. Tải HTML trang chi tiết môn học (`/course/view.php?id=[COURSE_ID]`).
3. Trích xuất các khối hoạt động bài tập `modtype_assign` qua regex:
   ```regex
   <li[^>]+class="[^"]*modtype_assign[^"]*"[^>]*>.*?<a[^>]+href="([^"]+)"[^>]*>(.*?)<\/a>
   ```
4. Kiểm tra trang nộp bài tập của sinh viên: Nếu HTML chứa các chuỗi nhận diện:
   * `"Đã nộp để chấm điểm"`
   * `"Submitted for grading"`
   * `"submissionstatussubmitted"`
   -> Bài tập lập tức được gắn cờ `isCompleted = true`.

---

## 3. Quy tắc Phân loại Trạng thái 3 Tab (Tri-State Classification)

Mỗi bài tập được mô hình hóa qua enum `DeadlineStatus`:

| Trạng thái | Điều kiện xác định | Giao diện hiển thị | Badge / Màu sắc |
| :--- | :--- | :--- | :--- |
| **Chưa tới hạn (Upcoming)** | `!isCompleted` VÀ `deadlineTime > DateTime.now()` | Tab 1 + Top 3 Widget Trang chủ | Màu xanh ngọc (Teal), đếm ngược *Còn N ngày / Còn N giờ* |
| **Đã quá hạn (Overdue)** | `!isCompleted` VÀ `deadlineTime <= DateTime.now()` | Tab 2 (Đã quá hạn) | Màu đỏ (Red), cảnh báo *Đã quá hạn* |
| **Đã hoàn thành (Completed)** | `isCompleted == true` | Tab 3 (Đã hoàn thành) | Màu xanh lá (Green), badge *✓ Đã nộp bài*, viền thẻ xanh |

---

## 4. Giao diện & Trải nghiệm Người dùng (UI/UX Implementation)

### 4.1. Widget Trang chủ (`HomeMoodleDeadlinesCard`)
* **Nguyên tắc tinh gọn:** Chỉ hiển thị **tối đa 3 bài tập gần nhất CHƯA TỚI HẠN**.
* **Đếm ngược thông minh:** Tự động tính toán khoảng cách thời gian từ hiện tại đến hạn nộp (`Còn N ngày`, `Còn N giờ`, `Sắp hết hạn!`).
* **Trạng thái rỗng:** Khi không có bài tập nào sắp đến hạn, hiển thị thông báo tích xanh *"Không có bài tập nào sắp tới hạn."*.
* **Nút "Xem tất cả":** Điều hướng nhanh vào màn hình chi tiết `/module/moodle_courses`.

### 4.2. Màn hình Chi tiết Hạn nộp (`CoursesScreen`)
* **TabBar 3 Tab:** Sử dụng `isScrollable: false` và `TabAlignment.fill` chống tràn màn hình.
* **Huy hiệu số đếm (Badge Counters):** Tích hợp số lượng bài tập trực tiếp trên từng Tab header (`Chưa tới hạn`, `Đã quá hạn (16)`, `Đã hoàn thành (7)`).
* **Thanh thống kê tổng quan (Metrics Strip):** 3 cột phân cách rõ ràng:
  * ⏰ **Sắp tới hạn:** `N`
  * ⚠️ **Quá hạn:** `N`
  * ✅ **Đã nộp:** `N`
* **Deep-Link 1-chạm:** Bấm vào bất kỳ thẻ bài tập nào sẽ tự động mở trực tiếp trang nộp bài tập tương ứng trên Moodle qua MethodChannel `openWebBrowser`.

---

## 5. Danh mục File Mã nguồn Liên quan

| Đường dẫn File | Chức năng kỹ thuật |
| :--- | :--- |
| `lib/src/features/courses/data/moodle_api_client.dart` | Quản lý CookieJar, SSL Bypass, Referer Headers, xác thực 303 Redirect và Sesskey |
| `lib/src/features/courses/data/moodle_repository.dart` | Hybrid Extraction: Gọi Moodle Calendar API và quét Deep-Scan bài tập đã nộp |
| `lib/src/features/courses/models/moodle_models.dart` | Data Model `MoodleDeadline`, phân loại `DeadlineStatus` và copyWith |
| `lib/src/features/courses/providers/moodle_providers.dart` | Riverpod Provider `moodleAllDeadlinesFutureProvider` quản lý state bất đồng bộ |
| `lib/src/features/courses/widgets/home_moodle_deadlines_card.dart` | Widget Trang chủ hiển thị 3 deadline sắp tới kèm bộ đếm ngược |
| `lib/src/features/courses/courses_screen.dart` | Giao diện 3 Tab, Metrics Strip, Badge Counters và điều hướng nộp bài |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Native Bridge `openWebBrowser` mở trình duyệt hệ thống |
