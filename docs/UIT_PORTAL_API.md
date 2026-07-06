# UIT Portal Unofficial API Documentation 🚀

Tài liệu này tổng hợp toàn bộ các API nội bộ của hệ thống UIT Portal (Next.js) được trích xuất trong quá trình xây dựng ứng dụng Mobile Native.

## 🔑 Cơ chế Xác thực (Authentication - SSO Scraping)
Hệ thống UIT Portal (Next.js) không cung cấp API Login trực tiếp (Username/Password) mà sử dụng luồng OIDC (OpenID Connect) redirect qua hệ thống Keycloak (Microsoft SSO) của trường (`sso.uit.edu.vn`).

Để lấy được **Session Cookie** hợp lệ cho Portal, ứng dụng Mobile giả lập (scrape) luồng trình duyệt như sau:

1. **Khởi tạo OIDC Flow:** Gọi `GET https://portal.uit.edu.vn/api/auth/login`. Portal sẽ trả về HTTP 302 redirect kèm một số cookie tạm thời (OIDC cookies). URL redirect trỏ sang trang đăng nhập Keycloak.
2. **Lấy HTML Form Keycloak:** Gọi `GET` vào URL redirect ở Bước 1. Trích xuất cookie của Keycloak (`KC_RESTART`, `AUTH_SESSION_ID`,...) và dùng Regex `id="kc-form-login"[^>]*action="([^"]+)"` để trích xuất URL `action` của form đăng nhập.
3. **Submit form đăng nhập:** Gọi `POST` vào URL `action` vừa lấy được, kèm body `username=[MSSV]`, `password=[Mật khẩu]` và `credentialId=`. Gửi kèm Keycloak cookie.
   - Nếu sai mật khẩu, server trả về `HTTP 200` (hiển thị lại trang báo lỗi).
   - Nếu đúng mật khẩu, server trả về `HTTP 302` redirect về lại Portal kèm param `code=...` (Authorization Code).
4. **Hoàn tất OIDC:** Gọi `GET` vào URL callback của Bước 3, kèm theo OIDC cookies (lấy ở Bước 1). Lúc này, Portal sẽ trả về cookie chính thức `session=...`.

**Sử dụng API:** 
Để gọi bất kì API nào bên dưới, bạn bắt buộc phải đính kèm Header:
```http
Cookie: session=[SESSION_COOKIE_Ở_BƯỚC_4];
```

---

## 📅 1. Thời Khóa Biểu (TKB)
Lấy danh sách các môn học trong tuần.

**Endpoint:** `/api/sinh-vien/tkb`
**Method:** `GET`

### Query Parameters
| Tham số | Kiểu dữ liệu | Mô tả | Ví dụ |
| :--- | :--- | :--- | :--- |
| `hocKy` | `int` | Học kỳ | `1`, `2`, `3` |
| `namHoc` | `int` | Năm học bắt đầu | `2025` (Cho NH 2025-2026) |
| `yearId` | `int` | ID nội bộ của năm học | `17` |
| `startDate` | `string` | Ngày bắt đầu lấy lịch | `"2026-03-01"` |

### Response Shape (JSON)
```json
{
  "hocKy": 1,
  "namHoc": 2025,
  "tiets": [
    {
      "id": "...",
      "maMonHoc": "IT001",
      "tenMonHoc": "Nhập môn Lập trình",
      "maLop": "IT001.O11",
      "ngay": "2026-03-02",
      "thu": 2,
      "tietBatDau": 1,
      "tietKetThuc": 5,
      "phong": "E1.1",
      "giangVien": "Nguyễn Văn A",
      "loaiLich": "Lý thuyết"
    }
  ]
}
```

---

## 💯 2. Bảng Điểm
Lấy toàn bộ lịch sử điểm số các môn học từ lúc nhập học.

**Endpoint:** `/api/sinh-vien/bang-diem`
**Method:** `GET`

### Response Shape (JSON)
API trả về ngay lập tức toàn bộ điểm số các học kỳ mà không cần tham số.
```json
{
  "namHocGroups": [
    {
      "listNamHoc": [
        {
          "hocKy": 1,
          "namHoc": 2025,
          "monHocs": [
            {
              "maMonHoc": "IT001",
              "tenMonHoc": "Nhập môn Lập trình",
              "soTinChi": 4,
              "diemQuocTe": "A",
              "diemHe4": 4.0,
              "diemHe10": 9.5
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 📝 3. Lịch Thi
Lấy lịch thi của sinh viên theo học kỳ.

**Endpoint:** `/api/sinh-vien/lich-thi`
**Method:** `POST`

### Request Body (JSON)
```json
{
  "hocKy": 1,
  "namHoc": 2025,
  "yearId": 17
}
```

### Response Shape (JSON)
```json
{
  "items": [
    {
      "maMonHoc": "IT001",
      "tenMonHoc": "Nhập môn Lập trình",
      "maLop": "IT001.O11",
      "ngayThi": "2026-05-15",
      "caThi": 1,
      "gioBatDau": "07:30",
      "gioKetThuc": "09:30",
      "phong": "E1.1",
      "kyThi": "Cuối kỳ"
    }
  ]
}
```

---

## 💰 4. Học Phí (Tuition)
Lấy thông vị chi tiết về học phí, công nợ và mã QR thanh toán.

**Endpoint:** `/api/sv/tuition`
**Method:** `POST`

### Request Body (JSON)
Bạn phải gửi chính xác danh sách các cột (fields) mà frontend Next.js mong muốn:
```json
{
  "tuition_field_list": [
    "id", "semester", "year_id", "tuition_amount", "tuition_credit_number",
    "must_be_paid", "paid", "remaining", "debt_in_advance", "payment_status",
    "late_payment_date", "paid_time", "note"
  ],
  "detail_field_list": [
    "id", "subject_id", "subject_code", "subject_name", "tuition_credit_number",
    "unit_price", "additional_tuition", "amount", "note"
  ]
}
```

### Response Shape (JSON)
```json
{
  "records": [
    {
      "id": "...",
      "period": "HK1 / 2025-2026",
      "tuition_amount": 15000000,
      "paid": 0,
      "remaining": 15000000,
      "payment_status": "Chưa thanh toán",
      "qr_code": "iVBORw0KGgoAAAANSUhEUg...",
      "detail_ids": [
        {
          "subject_name": "IT001 - Nhập môn lập trình",
          "unit_price": 500000,
          "amount": 2000000
        }
      ],
      "payment_ids": []
    }
  ]
}
```

---

## 👤 5. Hồ Sơ Sinh Viên (RSC Parsing)
**Cảnh báo:** API lấy hồ sơ không tồn tại ở dạng JSON thuần. Backend của Next.js gọi API nội bộ, render thành React Server Component (RSC) và trả về. Do đó, cần phải fetch chuỗi RSC thô và dùng Regex để bóc tách.

**Endpoint:** `/sinh-vien/ho-so`
**Method:** `GET`

### Headers bắt buộc
Để Next.js trả về chuỗi RSC thay vì HTML, bạn **BẮT BUỘC** phải đính kèm Header:
```http
RSC: 1
```

### Response Shape (Text/RSC)
Response trả về dạng text thô của Next.js (ví dụ: `0:["$@1",["$@2",null]]...`).
Để lấy JSON của Profile, bạn cần parse chuỗi và tìm kiếm block chứa key `"student_code"` hoặc `"full_name"`. 

*Mẹo: Tham khảo `lib/src/utils/rsc_parser.dart` trong mã nguồn dự án để xem cách trích xuất an toàn dữ liệu này.*

---

## 🏃 6. Lịch Sinh Hoạt & Ngoại Khóa
Lấy lịch các sự kiện ngoại khóa.

**Endpoint:** `/api/sinh-vien/lich-sinh-hoat`
**Method:** `GET`

### Query Parameters
| Tham số | Kiểu dữ liệu | Mô tả |
| :--- | :--- | :--- |
| `hocKy` | `int` | Học kỳ |
| `namHoc` | `int` | Năm học |
| `yearId` | `int` | ID nội bộ của năm học |

---

## 📊 7. Khảo Sát Giảng Dạy
Lấy danh sách các lớp học phần cần thực hiện đánh giá giảng dạy.

**Endpoint:** `/api/sinh-vien/khao-sat-giang-day`
**Method:** `POST`

### Request Body (JSON)
```json
{}
```

### Response Shape (JSON)
```json
{
  "items": [],
  "pendingCount": 5,
  "doneCount": 0
}
```

---

## 📦 8. Các API Dịch Vụ Khác (GET / JSON)
Bên cạnh các module lớn ở trên, UIT Portal cung cấp một loạt các endpoint API GET trả về JSON cho các dịch vụ sinh viên. 
Tất cả các API này đều dùng Method **`GET`**, bắt buộc Header `Cookie: session=...` và không yêu cầu query parameters phức tạp (thường trả về toàn bộ dữ liệu của sinh viên).

* **Điểm rèn luyện:** `/api/sinh-vien/diem-ren-luyen`
* **Gia hạn học phí:** `/api/sinh-vien/gia-han-hoc-phi`
* **Xin bảng điểm:** `/api/sinh-vien/xin-bang-diem`
* **Đăng ký Khóa luận:** `/api/sinh-vien/khoa-luan`
* **Đăng ký Tốt nghiệp:** `/api/sinh-vien/tot-nghiep`
* **Thôi học / Bảo lưu:** `/api/sinh-vien/thoi-hoc-bao-luu`
* **Phúc khảo điểm:** `/api/sinh-vien/phuc-khao`
* **Thẻ sinh viên:** `/api/sinh-vien/the-sinh-vien`
* **Đăng ký Giữ xe:** `/api/sinh-vien/gui-xe`
* **Đăng ký Bảo hiểm:** `/api/sinh-vien/bao-hiem`
* **Xin Giấy xác nhận sinh viên:** `/api/sinh-vien/giay-xac-nhan`
* **Xác nhận Chứng chỉ ngoại ngữ/tin học:** `/api/sinh-vien/xac-nhan-chung-chi`
* **Đăng ký Học bổng:** `/api/sinh-vien/hoc-bong`
* **Hỗ trợ sinh viên:** `/api/sinh-vien/ho-tro`

*Cấu trúc Response:* Các endpoint này thường trả về 1 Object JSON hoặc một mảng (List) chứa danh sách các đơn từ đã nộp (hoặc trạng thái đăng ký của sinh viên).

> **Đóng góp (Contribution):** Tài liệu này được biên soạn bởi cộng đồng open-source. Nếu bạn tìm ra thêm API ẩn nào của trường, hãy tạo Pull Request để bổ sung nhé!
