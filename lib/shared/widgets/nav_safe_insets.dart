// path: lib/shared/widgets/nav_safe_insets.dart
import 'package:flutter/material.dart';

/// List padding that clears the floating bottom-nav pill.
///
/// [AppShell] folds the pill's footprint into the MediaQuery bottom padding, and
/// a scroll view with `padding: null` picks that up automatically — but one with
/// an explicit padding opts out, so its last row ends up hidden behind the pill.
/// Screens inside the shell should use this instead of a bare `EdgeInsets.all`.
EdgeInsets navSafeInsets(BuildContext context, {double horizontal = 16, double top = 16}) =>
    EdgeInsets.fromLTRB(horizontal, top, horizontal, MediaQuery.of(context).padding.bottom + 16);
