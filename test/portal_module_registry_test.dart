import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/portal_module_registry.dart';

void main() {
  test('falls back to dashboard for unknown module ids', () {
    final module = PortalModuleRegistry.byId('unknown');

    expect(module.id, 'dashboard');
  });

  test('does not register retired web-only service routes', () {
    expect(
      PortalModuleRegistry.modules.map((module) => module.id),
      isNot(contains('services')),
    );
    expect(
      PortalModuleRegistry.modules.map((module) => module.path),
      isNot(contains('/services')),
    );
  });

  test('marks public notifications as native', () {
    final notifications = PortalModuleRegistry.byId('notifications');

    expect(notifications.status, PortalModuleStatus.nativeImplemented);
    expect(notifications.path, '/');
  });
}
