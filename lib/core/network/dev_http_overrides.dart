// path: lib/core/network/dev_http_overrides.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// DEBUG-ONLY networking override.
///
/// Some corporate networks (e.g. Cisco Umbrella / Secure Web Gateway) intercept
/// TLS and re-sign every HTTPS response with a private corporate CA. Flutter's
/// `dart:io` HttpClient validates against its own root set, so those connections
/// fail with `CERTIFICATE_VERIFY_FAILED` — even though the traffic is legitimate.
///
/// This override adds the bundled corporate CA to the trust anchors (on top of
/// the normal public roots) for every HttpClient the app creates. It is applied
/// ONLY in debug builds and must never be shipped to release — production traffic
/// must validate against the real public CA chain.
class DevHttpOverrides extends HttpOverrides {
  DevHttpOverrides(this._context);

  final SecurityContext _context;

  /// Builds a [SecurityContext] that keeps the default public roots and adds the
  /// corporate CA loaded from assets. Returns null (no override needed) if the
  /// cert can't be loaded so the app falls back to normal validation.
  static Future<DevHttpOverrides?> load() async {
    try {
      final pem = await rootBundle.load('assets/dev/corporate_ca.pem');
      final context = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificatesBytes(pem.buffer.asUint8List());
      return DevHttpOverrides(context);
    } catch (e) {
      debugPrint('DevHttpOverrides: corporate CA not loaded ($e); skipping.');
      return null;
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context ?? _context);
}
