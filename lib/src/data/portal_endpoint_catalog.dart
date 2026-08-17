enum PortalHttpMethod { get, post }

enum PortalEndpointStatus { verified, retired, unsupported, mutationBlocked }

class PortalEndpoint {
  const PortalEndpoint({
    required this.method,
    required this.path,
    this.scanWithoutParameters = true,
  });

  final PortalHttpMethod method;
  final String path;
  final bool scanWithoutParameters;

  @override
  bool operator ==(Object other) =>
      other is PortalEndpoint && other.method == method && other.path == path;

  @override
  int get hashCode => Object.hash(method, path);
}

class PortalEndpointCatalog {
  const PortalEndpointCatalog._();

  static const List<PortalEndpoint> verifiedEndpoints = [
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/public/announcements',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/tkb',
      scanWithoutParameters: false,
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/lich-sinh-hoat',
      scanWithoutParameters: false,
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/giay-xac-nhan',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/xac-nhan-chung-chi',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/bang-diem',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/diem-ren-luyen',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/xin-bang-diem',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/hoan-thi',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/phuc-khao',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/the-sinh-vien',
    ),
    PortalEndpoint(method: PortalHttpMethod.get, path: '/api/sinh-vien/gui-xe'),
    PortalEndpoint(method: PortalHttpMethod.post, path: '/api/sinh-vien/gui-xe'),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/khoa-luan',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/tot-nghiep',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/hoc-bong',
    ),
    PortalEndpoint(method: PortalHttpMethod.get, path: '/api/sinh-vien/ho-tro'),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/bao-hiem',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/gia-han-hoc-phi',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.get,
      path: '/api/sinh-vien/thoi-hoc-bao-luu',
    ),
    PortalEndpoint(method: PortalHttpMethod.post, path: '/api/sv/tuition'),
    PortalEndpoint(
      method: PortalHttpMethod.post,
      path: '/api/sinh-vien/lich-thi',
    ),
    PortalEndpoint(
      method: PortalHttpMethod.post,
      path: '/api/sinh-vien/khao-sat-giang-day',
    ),
  ];

  static const endpointStatuses = <String, PortalEndpointStatus>{
    '/api/sinh-vien/hoc-phi': PortalEndpointStatus.retired,
    '/api/sinh-vien/dang-vien': PortalEndpointStatus.retired,
    '/api/sinh-vien/de-tai-sinh-vien': PortalEndpointStatus.unsupported,
    '/api/sv/exam-schedule': PortalEndpointStatus.retired,
    '/api/vc-nld/notifications?limit=20': PortalEndpointStatus.unsupported,
    '/api/sinh-vien/tkb/dang-ky': PortalEndpointStatus.mutationBlocked,
    '/api/sv/scholarship-kkht/register': PortalEndpointStatus.mutationBlocked,
  };

  static const replacements = <String, PortalEndpoint>{
    '/api/sinh-vien/hoc-phi': PortalEndpoint(
      method: PortalHttpMethod.post,
      path: '/api/sv/tuition',
    ),
    '/api/sv/exam-schedule': PortalEndpoint(
      method: PortalHttpMethod.post,
      path: '/api/sinh-vien/lich-thi',
    ),
  };

  static List<String> get scannableGetPaths => verifiedEndpoints
      .where(
        (endpoint) =>
            endpoint.method == PortalHttpMethod.get &&
            endpoint.scanWithoutParameters,
      )
      .map((endpoint) => endpoint.path)
      .toList(growable: false);

  static PortalEndpoint? replacementFor(String path) => replacements[path];

  static bool verified(PortalEndpoint endpoint) =>
      verifiedEndpoints.contains(endpoint);
}
