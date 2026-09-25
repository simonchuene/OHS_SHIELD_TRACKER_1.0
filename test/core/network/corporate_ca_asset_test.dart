// path: test/core/network/corporate_ca_asset_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The corporate TLS-inspection CA is bundled only into the `dev` flavor
/// (pubspec.yaml). It used to be listed unconditionally, so the certificate
/// shipped inside every build — release and prod included — even though the
/// code only ever reads it in debug.
///
/// This pins the fix in both directions. CI runs `flutter test` with no flavor,
/// which is also how uat/prod see the asset list: there the file must be absent.
/// Under `flutter test --flavor dev` it must still be present, or the debug
/// workaround it exists for would silently stop working.
///
/// Asserted against the ASSET MANIFEST, not by loading the file. The test
/// harness serves assets straight from build/unit_test_assets by path, and a
/// file left there by an earlier build survives a flavor change — so a load can
/// succeed for a file the current bundle does not contain. The manifest is
/// regenerated with the bundle and says what it actually holds.
///
/// If this fails locally right after an edit to pubspec assets, delete
/// build/unit_test_assets and rerun: `flutter test` with no flavor was observed
/// reusing a stale test bundle across a pubspec change (a flavor change does
/// force a rebuild). CI builds from a clean checkout and is unaffected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = 'assets/dev/corporate_ca.pem';

  test('corporate CA is bundled only into the dev flavor', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().contains(path);

    expect(bundled, appFlavor == 'dev',
        reason: 'flavor "$appFlavor": the CA must be bundled only into dev',);

    if (bundled) {
      final pem = await rootBundle.load(path);
      expect(pem.lengthInBytes, greaterThan(0),
          reason: 'dev must carry a non-empty CA',);
    }
  });
}
