// path: lib/core/utils/user_lookup.dart

/// Resolve a user id to a display name against a roster.
///
/// Safety records store only the user id (`owner_id`, `investigator_id`,
/// `reporter_id`), so screens showing a person's name have to look it up.
///
/// Structurally typed on the record shape rather than importing a feature's
/// `NamedUser`, so any screen can use it without depending on the CAPA feature.
///
/// Returns null when there is no id, the roster has not loaded, the user is
/// outside the caller's RLS-visible scope, or the name is blank — callers should
/// fall back to something neutral rather than rendering an empty label or a raw
/// UUID.
String? nameForUser(
  Iterable<({String id, String name})>? users,
  String? userId,
) {
  if (userId == null || users == null) return null;
  for (final u in users) {
    if (u.id == userId) {
      final name = u.name.trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}
