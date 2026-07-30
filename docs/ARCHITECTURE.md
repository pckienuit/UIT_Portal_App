# Architecture

## Mục tiêu

Ứng dụng là Android client native cho dữ liệu UIT Portal và cấu hình AI của người dùng. Không có backend do dự án vận hành để relay session Portal hoặc credential AI.

## Thành phần

```text
Flutter presentation + Riverpod
        |
        +-- Dio / Portal services --> portal.uit.edu.vn + sso.uit.edu.vn
        |
        +-- MethodChannel --> Kotlin Android bridge
                                  |
                                  +-- JNI/C++ --> embedded Node runtime
                                                   |
                                                   +-- 127.0.0.1 Core AI API
```

- `lib/`: UI Flutter, Riverpod state, Portal services và AI providers.
- `android/app/src/main/kotlin/`: MethodChannel, OAuth native, lifecycle Core AI.
- `android/app/src/main/cpp/`: JNI bridge sang Node runtime.
- `android/app/src/main/assets/nodejs-project/`: adapter và provider catalog cho embedded Core AI.
- `tools/9router_mobile/`: catalog audit/sync tooling.

## Bảo mật boundary

### Portal

- Session/cookie và token được secure storage quản lý trên thiết bị.
- Tài liệu API chỉ lưu request/response đã sanitize.
- Không gửi raw HAR, credentials hoặc dữ liệu sinh viên vào source control.

### AI Core

- Kotlin cấp port tạm và bearer ngẫu nhiên cho mỗi runtime start.
- API local dùng `127.0.0.1`; không được bind `0.0.0.0`. Release chỉ cho phép HTTP cleartext tới localhost và loopback. `10.0.2.2` chỉ có trong resource `debug` cho Ollama trên Android Emulator, không có trong APK release.
- User credential được lưu qua Flutter secure storage, không đưa vào Node persisted state.
- Chia sẻ ngữ cảnh Portal theo allowlist và lựa chọn rõ ràng của người dùng.

### OAuth

- APK là public client. OAuth client secret không được tồn tại trong code, asset hoặc Gradle.
- Provider desktop OAuth có confidential credential bị chặn khỏi Android public catalog.
- Các public flow phải có contract test và provider-side registration trước khi bật lại.

## Release boundary

`android/app/libnode/` là native runtime build input, không được track. Một clone công khai không tự build được APK cho tới khi runtime ABI tương thích được provision. Xem [RELEASING.md](RELEASING.md).
