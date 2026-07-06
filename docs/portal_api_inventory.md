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
