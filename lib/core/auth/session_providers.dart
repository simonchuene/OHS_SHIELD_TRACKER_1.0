// path: lib/core/auth/session_providers.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Foundation-level session state (session presence only). The full
/// Authentication module (Prompt 5) builds sign-in/out, RBAC role loading, and
/// secure session management on top of these primitives.

/// Emits the current [Session] (or null) and updates on every auth change.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// True when a session exists. Used by the router redirect.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Recompute when auth changes.
  ref.watch(authStateChangesProvider);
  return client.auth.currentSession != null;
});

// Role rank for the router guard is provided by the Auth feature
// (`authRoleRankProvider` in features/auth) as of Prompt 5.

/// Adapts a [Stream] to a [Listenable] for GoRouter.refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
