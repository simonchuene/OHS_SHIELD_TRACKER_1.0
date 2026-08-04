// path: lib/main.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/app.dart';
import 'package:ohs_shield_tracker/core/config/app_config.dart';
import 'package:ohs_shield_tracker/core/network/dev_http_overrides.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug-only: trust a corporate TLS-inspection CA so the app can reach Supabase
  // from behind a Cisco Umbrella gateway (never applied in release builds).
  if (kDebugMode) {
    final overrides = await DevHttpOverrides.load();
    if (overrides != null) HttpOverrides.global = overrides;
  }

  final config = AppConfig.fromEnvironment();

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const OhsShieldApp(),
    ),
  );
}
