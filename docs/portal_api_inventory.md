# Portal API Inventory

This file is intentionally empty until authenticated endpoint discovery starts.

When authenticated API discovery starts, record only sanitized endpoint details:
method, path, request shape, response shape, and the screen/module that uses it.
Never store cookies, tokens, passwords, raw HAR exports, or personal student data.

## Template

```text
Module:
Screen:
Endpoint:
Method:
Auth source: OIDC bearer token | server session cookie | blocked
Request shape:
Response shape:
Native status: planned | implemented | blockedExternal
Notes:
```

## Discovery Rules

- Capture only endpoints required by the app module being native-ized.
- Replace all IDs, names, emails, class codes, tokens, cookies, and timestamps
  with placeholders before saving notes here.
- If an endpoint cannot be verified safely, keep the module in native pending
  state and mark it `blockedExternal`; do not reintroduce WebView fallback.

## 1. Thời Khóa Biểu (TKB)

```text
Module: TKB (Thời khóa biểu)
Screen: ScheduleScreen
Endpoint: /api/sinh-vien/tkb
Method: GET
Auth source: server session cookie
Request shape:
  Query Parameters:
  - hocKy (int): Học kỳ (vd: 1, 2)
  - namHoc (int): Năm học bắt đầu (vd: 2025 cho năm 2025-2026)
  - yearId (int): ID định danh của năm học trên hệ thống (vd: 17)
  - startDate (string): Ngày bắt đầu tính lịch (vd: "2026-03-01")
Response shape:
  JSON Object:
  - hocKy (int)
  - namHoc (int)
  - tiets (List of Objects):
    - id (string)
    - maLop (string)
    - maMonHoc (string)
    - tenMonHoc (string)
    - ngay (string - YYYY-MM-DD)
    - thu (int - 2 đến 8)
    - tietBatDau (int)
    - tietKetThuc (int)
    - phong (string)
    - giangVien (string)
    - loaiLich (string)
Native status: implemented
Notes: 
- Ban đầu nhầm lẫn rằng Next.js giấu dữ liệu trong RSC Payload. Tuy nhiên, qua Network Tab phát hiện Portal cung cấp sẵn API JSON thuần.
- Việc API trả về lỗi 400 Bad Request là do thiếu các tham số bắt buộc (đặc biệt là yearId và startDate), không phải do cơ chế chống scraping của Next.js.
```

## 2. Bảng Điểm

```text
Module: Bảng điểm
Screen: GradesScreen
Endpoint: /api/sinh-vien/bang-diem
Method: GET
Auth source: server session cookie
Request shape: Không yêu cầu tham số để lấy toàn bộ điểm
Response shape:
  JSON Object:
  - namHocGroups (List)
    - hk (int)
    - listNamHoc (List)
      - hocKy (int)
      - namHoc (int)
      - monHocs (List of Objects)
Native status: implemented
Notes: Trả về toàn bộ lịch sử điểm của sinh viên trong một lần gọi.
```

## 3. Lịch Thi

```text
Module: Lịch thi
Screen: ExamScheduleScreen (planned)
Endpoint: /api/sinh-vien/lich-thi
Method: POST
Auth source: server session cookie
Request shape:
  JSON Body:
  - hocKy (int | string)
  - namHoc (int | string)
  - yearId (int | string)
Response shape:
  JSON Object:
  - items (List of Objects):
    - id (string)
    - maMonHoc (string)
    - tenMonHoc (string)
    - maLop (string)
    - ngayThi (string - YYYY-MM-DD)
    - caThi (int)
    - gioBatDau (string - HH:MM)
    - gioKetThuc (string - HH:MM)
    - tietBatDau (int)
    - tietKetThuc (int)
    - phong (string)
    - hinhThuc (string)
    - kyThi (string)
Native status: planned
Notes: Bắt buộc dùng POST thay vì GET.
```

## 4. Lịch Sinh Hoạt

```text
Module: Lịch sinh hoạt (Ngoại khóa)
Screen: ExtracurricularScreen (planned)
Endpoint: /api/sinh-vien/lich-sinh-hoat
Method: GET
Auth source: server session cookie
Request shape:
  Query Parameters:
  - hocKy (int | string)
  - namHoc (int | string)
  - yearId (int | string)
Response shape:
  JSON Object:
  - items (List of Objects)
Native status: planned
Notes: Có thể trả về danh sách trống `{"items": []}` nếu không có lịch.
```

## 5. Khảo sát giảng dạy

```text
Module: Khảo sát
Screen: TeachingSurveyScreen (planned)
Endpoint: /api/sinh-vien/khao-sat-giang-day
Method: POST
Auth source: server session cookie
Request shape:
  JSON Body: {} (Chưa rõ tham số bắt buộc)
Response shape:
  JSON Object:
  - items (List)
  - pendingCount (int)
  - doneCount (int)
Native status: planned
Notes: Bắt buộc dùng POST thay vì GET.
```

## 7. Đăng Ký Gửi Xe

```text
Module: Gửi xe
Screen: ParkingRegistrationScreen
Endpoint: /api/sinh-vien/gui-xe
Methods: 
  - GET: Lấy danh sách lịch sử đăng ký gửi xe
  - POST: Gửi đơn đăng ký gửi xe mới
Auth source: server session cookie
Request shape (POST):
  JSON Body:
  - license_plate_number (string): Biển số xe (vd: "59X3-12345")
  - vehicle_type (string): Loại xe ("motorcycle", "bicycle", "electric_bicycle")
  - number_of_months (int): Số tháng gửi (1 đến 12)
Response shape:
  JSON Object (hoặc ParkingRecord)
Native status: implemented
```


- **Hồ sơ sinh viên**: `/api/sinh-vien/ho-so` -> 404 Not Found.
- **Học phí**: `/api/sinh-vien/hoc-phi` -> 404 Not Found.
- **Đảng viên**: `/api/sinh-vien/dang-vien` -> 404 Not Found.
*Giải pháp*: Cần gọi trực tiếp URL giao diện `/sinh-vien/...` kèm header `RSC: 1` và `Next-Router-State-Tree` để lấy chuỗi RSC, sau đó dùng Regex hoặc `RscParser` bóc tách dữ liệu JSON bị nhúng trong Component Tree.
