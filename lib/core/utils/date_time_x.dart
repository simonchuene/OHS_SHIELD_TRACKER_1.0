// path: lib/core/utils/date_time_x.dart

/// Display helpers for timestamps that cross the Postgres boundary.
extension LocalDateTimeX on DateTime {
  /// The same instant in the device's timezone, ready to format.
  ///
  /// Postgres `timestamptz` columns serialise with an offset (`...Z` /
  /// `+00:00`), so `DateTime.parse` yields a **UTC** `DateTime`. `DateFormat`
  /// prints that value's own wall-clock, which renders every timestamp N hours
  /// behind for any user east of UTC — 2 hours in CAT/SAST (UTC+2).
  ///
  /// Guarded on [isUtc] so it is a no-op for values that are already local:
  /// notably `date` columns (`due_date`, `scheduled_date`), which parse as
  /// local midnight. Blindly calling `toLocal()` on those would be harmless
  /// today but would shift the day for users west of UTC.
  ///
  /// Only for display. Never convert before sending a value back to the server
  /// — `toIso8601String()` on a UTC instant is already correct.
  DateTime get local => isUtc ? toLocal() : this;
}
