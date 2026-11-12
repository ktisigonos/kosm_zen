//! Zen Browser: its colors and tab animation through a Zen mod kosm writes, and its about:config
//! prefs in every profile's user.js.

const std = @import("std");

/// Zen's theme colors and prefs; build one with `from`.
pub const App = @import("App.zig");
/// Colors and prefs from the theme.
pub const from = App.from;
/// Prefs and the kosm mod for a set of profiles, an app of its own; build one with `Profile.from`.
pub const Profile = App.Profile;
/// The kosm mod's values, for a `Profile`; build them with `Mod.from`.
pub const Mod = App.Mod;
/// The adapter the mod's stylesheet is written with, so a config needs only this package to rice Zen.
pub const css_adapter = @import("kosm_css").adapter;
/// The adapter the mod's list of prefs and Zen's mod list are written with.
pub const json_adapter = @import("kosm_json").adapter;
/// The adapter the prefs are written with.
pub const userjs_adapter = @import("kosm_userjs").adapter;

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(App);
    std.testing.refAllDecls(Profile);
    std.testing.refAllDecls(Mod);
    _ = @import("user_js.zig");
}
