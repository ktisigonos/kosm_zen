//! Zen's `zen.mods.*` prefs: its mods and their updates.

/// `last-update`: when Zen last checked the mod store for updates, in seconds since 1970. Zen
/// checks again at startup once it is older than its update interval or is -1, and the check
/// rebuilds every mod's stylesheet from disk. null: -1 while the profile writes the kosm mod, so
/// a change to the mod's stylesheet shows after a restart, at the cost of asking the store for
/// updates a moment after every start; else Zen's own.
last_update: ?i32 = null,
