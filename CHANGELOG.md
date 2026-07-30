# Changelog

Tất cả thay đổi đáng chú ý được ghi tại đây.

## [1.0.0] - 2026-07-29

### Added

- Phát hành Android đầu tiên cho UIT Portal Mobile.
- Các màn hình Portal native và trợ lý AI có cấu hình provider.
- Core AI nội bộ chạy loopback với bearer ngẫu nhiên theo phiên chạy.
- Tài liệu open-source, security policy, contributing guide và quy trình release.

### Security

- Không đưa Google desktop OAuth providers cần client secret vào public Android registry.
- Bản public chặn Gemini CLI và Antigravity native OAuth cho tới khi có public Android OAuth flow được provider hỗ trợ.
- Release signing dùng keystore local, không dùng debug key.

[1.0.0]: https://github.com/pckienuit/UIT_Portal_App/releases/tag/v1.0.0
