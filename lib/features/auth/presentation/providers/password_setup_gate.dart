// path: lib/features/auth/presentation/providers/password_setup_gate.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';

/// Holds "this session arrived by email link and still has no password".
///
/// A `ChangeNotifier` rather than a Riverpod state object so the router can take
/// it in `refreshListenable` alongside the auth stream — the redirect has to
/// re-run the moment the flag flips, and GoRouter only listens to `Listenable`s.
/// Mirrors how `splashGateProvider` is wired.
class PasswordSetupGate extends ChangeNotifier {
  bool _required = false;
  bool get required => _required;

  void flag() {
    if (_required) return;
    _required = true;
    notifyListeners();
  }

  void clear() {
    if (!_required) return;
    _required = false;
    notifyListeners();
  }
}

/// Whether a recovery link was processed before the widget tree existed.
///
/// A link that *launches* the app — the normal case, since tapping it in a mail
/// client cold-starts the process — is handled by `supabase_flutter` during
/// startup, and `passwordRecovery` can fire before Riverpod has built any
/// provider. A stream listener created later never sees it: the event is gone,
/// and the user lands on the dashboard with a session they cannot recreate.
///
/// So the subscription starts in `main()`, before `runApp`, and parks the result
/// here for the gate to pick up. `ValueNotifier` rather than a bare bool so a
/// late-built gate is still notified if the event arrives mid-startup.
final earlyPasswordRecovery = ValueNotifier<bool>(false);

/// Starts watching for recovery events immediately after `Supabase.initialize()`.
/// Must be called before `runApp` — that is the entire point.
void watchEarlyPasswordRecovery(SupabaseClient client) {
  client.auth.onAuthStateChange.listen((s) {
    if (s.event == AuthChangeEvent.passwordRecovery) earlyPasswordRecovery.value = true;
  });
}

/// Raises the gate for the two ways a session can exist without a password.
///
/// **Reset** is event-driven: Supabase emits `passwordRecovery` when a recovery
/// link completes.
///
/// **Invite** cannot use events — an invite link emits a plain `signedIn`,
/// indistinguishable from an ordinary login. It is detected from server state
/// instead: migration 0020 holds `user_profiles.status = 'invited'` until a
/// password is actually set, so an invited profile *is* the signal that
/// onboarding is unfinished. That is authoritative rather than inferred, and it
/// survives the app being killed mid-flow — the user is re-gated on next launch
/// rather than stranded with an unusable account.
final passwordSetupGateProvider = Provider<PasswordSetupGate>((ref) {
  final gate = PasswordSetupGate();

  // A recovery event caught before the tree existed (see above). Checked on
  // creation *and* listened to, because startup ordering is not guaranteed:
  // the gate may be built either side of the link being processed.
  if (earlyPasswordRecovery.value) gate.flag();
  void onEarly() {
    if (earlyPasswordRecovery.value) gate.flag();
  }
  earlyPasswordRecovery.addListener(onEarly);

  // Recovery links arriving while the app is already running.
  final sub = ref.watch(supabaseClientProvider).auth.onAuthStateChange.listen((s) {
    if (s.event == AuthChangeEvent.passwordRecovery) gate.flag();
  });

  // Invited profile => onboarding incomplete. `listen` rather than `watch`: this
  // provider must not rebuild (and drop the gate) as the user loads.
  ref.listen(currentUserProvider, (_, next) {
    final status = next.valueOrNull?.status;
    if (status == UserStatus.invited) gate.flag();
  }, fireImmediately: true,);

  ref.onDispose(() {
    sub.cancel();
    earlyPasswordRecovery.removeListener(onEarly);
    gate.dispose();
  });
  return gate;
});
