import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/data/portal_endpoint_catalog.dart';

void main() {
  group('PortalEndpointCatalog', () {
    test('keeps only verified read endpoints in scanner catalog', () {
      final scanned = PortalEndpointCatalog.scannableGetPaths;

      expect(scanned, contains('/api/public/announcements'));
      expect(scanned, isNot(contains('/api/sinh-vien/hoc-phi')));
      expect(scanned, isNot(contains('/api/sinh-vien/dang-vien')));
      expect(scanned, isNot(contains('/api/sinh-vien/de-tai-sinh-vien')));
      expect(scanned, isNot(contains('/api/sv/exam-schedule')));
      expect(scanned, isNot(contains('/api/vc-nld/notifications?limit=20')));
    });

    test('records verified replacements for retired endpoints', () {
      expect(
        PortalEndpointCatalog.replacementFor('/api/sinh-vien/hoc-phi'),
        const PortalEndpoint(
          method: PortalHttpMethod.post,
          path: '/api/sv/tuition',
        ),
      );
      expect(
        PortalEndpointCatalog.replacementFor('/api/sv/exam-schedule'),
        const PortalEndpoint(
          method: PortalHttpMethod.post,
          path: '/api/sinh-vien/lich-thi',
        ),
      );
    });

    test(
      'keeps public announcements, tuition, exam, and survey methods exact',
      () {
        expect(
          PortalEndpointCatalog.verified(
            const PortalEndpoint(
              method: PortalHttpMethod.get,
              path: '/api/public/announcements',
            ),
          ),
          isTrue,
        );
        expect(
          PortalEndpointCatalog.verified(
            const PortalEndpoint(
              method: PortalHttpMethod.get,
              path: '/api/sinh-vien/tkb',
            ),
          ),
          isTrue,
        );
        expect(
          PortalEndpointCatalog.verified(
            const PortalEndpoint(
              method: PortalHttpMethod.get,
              path: '/api/sinh-vien/lich-sinh-hoat',
            ),
          ),
          isTrue,
        );
        expect(
          PortalEndpointCatalog.verified(
            const PortalEndpoint(
              method: PortalHttpMethod.post,
              path: '/api/sv/tuition',
            ),
          ),
          isTrue,
        );
        expect(
          PortalEndpointCatalog.verified(
            const PortalEndpoint(
              method: PortalHttpMethod.post,
              path: '/api/sinh-vien/lich-thi',
            ),
          ),
          isTrue,
        );
        expect(
          PortalEndpointCatalog.scannableGetPaths,
          isNot(contains('/api/sv/tuition')),
        );
        expect(
          PortalEndpointCatalog.scannableGetPaths,
          isNot(contains('/api/sinh-vien/lich-thi')),
        );
        expect(
          PortalEndpointCatalog.scannableGetPaths,
          isNot(contains('/api/sinh-vien/tkb')),
        );
        expect(
          PortalEndpointCatalog.scannableGetPaths,
          isNot(contains('/api/sinh-vien/lich-sinh-hoat')),
        );
      },
    );

    test('keeps verified methods exact', () {
      expect(
        PortalEndpointCatalog.verified(
          const PortalEndpoint(
            method: PortalHttpMethod.post,
            path: '/api/sinh-vien/khao-sat-giang-day',
          ),
        ),
        isTrue,
      );
      expect(
        PortalEndpointCatalog.verified(
          const PortalEndpoint(
            method: PortalHttpMethod.get,
            path: '/api/sinh-vien/khao-sat-giang-day',
          ),
        ),
        isFalse,
      );
    });
  });
}
