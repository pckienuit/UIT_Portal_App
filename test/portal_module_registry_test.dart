import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/portal_constants.dart';
import 'package:uit_portal_app/src/portal_module_registry.dart';

void main() {
  test('falls back to dashboard for unknown module ids', () {
    final module = PortalModuleRegistry.byId('unknown');

    expect(module.id, 'dashboard');
  });

  test('builds portal web URLs from the official origin', () {
    final module = PortalModuleRegistry.byId('notifications');

    expect(
      module.webUri.toString(),
      '${PortalConstants.portalOrigin}/notifications',
    );
  });
}
