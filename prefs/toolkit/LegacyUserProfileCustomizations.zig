//! Firefox's `toolkit.legacyUserProfileCustomizations.*` prefs.

/// `stylesheets`: read the profile's `userChrome.css` and `userContent.css`. null: not
/// written (Firefox: false); the kosm mod doesn't need it.
stylesheets: ?bool = null,
