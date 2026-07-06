# Tóm tắt ngữ cảnh và Handoff cho Session mới

## 1. Ngữ cảnh hiện tại (Những gì đã đạt được)
Chúng ta đang trong quá trình chuyển đổi toàn bộ **UIT Portal Mobile** từ WebView (Next.js) sang **Native Flutter**.
Đến thời điểm này, chúng ta đã **hoàn thành xuất sắc Phase 1 & 2**, cụ thể:

* **Công cụ hỗ trợ đắc lực:** Đã xây dựng `ApiDebuggerScreen` ngay trong app, cho phép gọi thử các API với Cookie định danh SSO gắn sẵn để dịch ngược cấu trúc dữ liệu trả về từ server của trường.
* **Tích hợp thành công 5 Module Native 100%:**
  1. **Thời khóa biểu** (`/api/sinh-vien/tkb` - GET)
  2. **Bảng điểm** (`/api/sinh-vien/bang-diem` - GET)
  3. **Lịch thi** (`/api/sinh-vien/lich-thi` - POST) - Có tính năng tự động sắp xếp theo thời gian mới nhất và gom nhóm theo "Kỳ thi - Năm học".
  4. **Khảo sát giảng dạy** (`/api/sinh-vien/khao-sat-giang-day` - POST)
  5. **Lịch sinh hoạt / Ngoại khóa** (`/api/sinh-vien/lich-sinh-hoat` - GET)
* **Kiến trúc mã nguồn:** Sử dụng kiến trúc hiện đại, gọn nhẹ: `GoRouter` (điều hướng), `Riverpod` (quản lý state/caching), `Dio` (gọi API), và các Model thuần Dart (do không dùng `freezed` để tránh lỗi build_runner tại máy local). Tài liệu API được ghi chép đầy đủ tại `docs/portal_api_inventory.md`.

---

## 2. Mục tiêu của Phase 3 (Nhiệm vụ cho Session mới)
Phase 3 là thử thách lớn nhất: **Xử lý các tính năng KHÔNG CÓ API thuần**. 
Khi ta gọi vào `/api/sinh-vien/ho-so` hoặc `/api/sinh-vien/hoc-phi`, server trả về lỗi `404 Not Found`. Lý do là Next.js không tách riêng API mà nhúng thẳng dữ liệu JSON vào bên trong **RSC Payload (React Server Components)**.

### Các bước triển khai trong Session mới:
1. **Lấy mẫu dữ liệu RSC:**
   * Mở app, vào màn hình **API Debugger**.
   * Nhập URL của trang web (Ví dụ: `/sinh-vien/ho-so`).
   * **Quan trọng:** Tích chọn nút *“Gửi kèm header RSC: 1”*.
   * Bấm GET. Trình duyệt sẽ trả về một chuỗi văn bản rất dài, lộn xộn chứa mã RSC của Next.js.
   * Copy toàn bộ chuỗi này cung cấp cho AI ở session mới.

2. **Viết RSC Parser (Trình phân tích cú pháp):**
   * Phân tích chuỗi RSC vừa lấy được để tìm quy luật nơi chứa dữ liệu JSON thật (thường nằm sau một ký tự đặc biệt hoặc một mảng mã hóa của Next.js).
   * Tạo class `RscParser` trong Dart sử dụng Regex hoặc thuật toán xử lý chuỗi (String manipulation) để bóc tách thành công đoạn JSON chứa thông tin sinh viên từ đống lộn xộn đó.

3. **Xây dựng Native UI cho Hồ sơ sinh viên:**
   * Tạo Data Model (`ProfileModel`) từ JSON đã bóc tách được.
   * Viết Provider sử dụng `Dio` để gọi API và truyền qua `RscParser`.
   * Thiết kế màn hình `ProfileScreen` hiển thị thông tin cá nhân.

*Tip cho session mới:* Bạn chỉ cần đính kèm hoặc copy nội dung file `session_handoff.md` này kèm theo chuỗi RSC bạn bắt được từ app là trợ lý AI mới có thể bắt nhịp và làm việc ngay lập tức!
