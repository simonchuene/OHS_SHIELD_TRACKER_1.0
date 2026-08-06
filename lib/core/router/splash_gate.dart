// path: lib/core/router/splash_gate.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the branded splash stays on screen once Flutter starts drawing it.
/// The countdown is started by the splash widget itself (not at app init) — the
/// native launch screen already covers the first second or so of startup, so a
/// timer started earlier would elapse before the Flutter splash ever appears.
const splashHold = Duration(milliseconds: 1600);

/// Flips true when [splashHold] has elapsed. Wired into the router's
/// refreshListenable so the splash redirect is re-evaluated once it expires.
final splashGateProvider = Provider<ValueNotifier<bool>>((ref) {
  final gate = ValueNotifier(false);
  ref.onDispose(gate.dispose);
  return gate;
});
