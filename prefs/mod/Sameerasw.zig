//! The Transparent Zen mod's `mod.sameerasw.*` prefs: the color behind the whole browser.

const kosm = @import("kosm");

/// `zen_bg_color_enabled`: tint the browser's background with `zen_transparency_color`.
/// null: `true` when the profile's page background is not opaque, else the mod's, false.
zen_bg_color_enabled: ?bool = null,
/// `zen_transparency_color`: the browser's background, alpha included. null: the profile's
/// page background when that is not opaque, else the mod's own.
zen_transparency_color: ?kosm.Color = null,

/// Pref names that differ from the field names' `_` -> `-` spelling.
pub const pref_names = .{ .zen_bg_color_enabled = "zen_bg_color_enabled", .zen_transparency_color = "zen_transparency_color" };
