//! Zen Browser: its colors and tab animation through the kosm mod, a Zen mod kosm writes into
//! every profile, and its about:config prefs in every profile's `user.js`, both through
//! `profile`. Zen reads them when it starts.

const App = @This();

const std = @import("std");
const kosm = @import("kosm");

/// Text and icons (`--kosm-foreground`), for your own styles. null: not written. `from`: the
/// foreground role.
foreground: ?kosm.Color = null,
/// Links, focused fields and the selected tab's text (`--kosm-accent`), for your own styles.
/// null: not written. `from`: the accent role.
accent: ?kosm.Color = null,
/// The window behind pages, the compact sidebar, the sidebar panel and glance
/// (`--kosm-background`), alpha included. null: not written, and Zen keeps its own background.
/// `from`: the background role at the theme's `background_alpha`.
background: ?kosm.Color = null,
/// Buttons and the toolbar (`--kosm-button`), for your own styles. null: not written. `from`:
/// `surface.raised` of `background`.
button: ?kosm.Color = null,
/// Buttons under the pointer (`--kosm-button-hovered`), for your own styles. null: `hovered` of
/// `button` when both are set, else not written.
button_hovered: ?kosm.Color = null,
/// Glance's outline (`--kosm-border`). null: not written; glance keeps a faint white one.
/// `from`: the accent role.
border: ?kosm.Color = null,
/// Container tab colors (`--kosm-containers-blue`, ...), for your own styles. null ones are not
/// written. `from`: the wheel's hues.
containers: Containers = .{},
/// Makes `button_hovered` from `button` when it is null. null: nothing derived.
/// `from`: the theme's `state.hovered`.
hovered: ?kosm.Modifier = null,
/// How a page zooms in when its tab is selected. null: it doesn't. `from`:
/// `Mod.default_tab_switch`, 0.25 s with a slight overshoot.
tab_switch: ?Mod.TabSwitch = null,
/// The floating sidebar of compact mode: its width, and whether the page beneath is cut out
/// (x-ray) or blurred. null: Zen's own, the page showing through. `from`:
/// `Mod.default_compact_sidebar`, x-ray at 186 px.
compact_sidebar: ?Mod.CompactSidebar = null,
/// Properties the app doesn't cover, each a pref named by `path` that Zen sets as the property
/// of that name with `.` as `-`: `.{ .path = "kosm.tab.radius", .value = .{ .raw = "8px" } }` is
/// `--kosm-tab-radius`. A name another pref has fails the apply. Default: none.
extra: []const kosm.Setting = &.{},
/// Zen's logo in the theme's colors, for user styles to show. null: not written. `from`: the
/// background and foreground.
logo: ?Logo = null,
/// The profiles that get the kosm mod with the values above, and their about:config prefs.
/// null: nothing but the logo is written, e.g. on a machine without Zen. `from`:
/// `Profile.from(theme)` for every profile.
profile: ?Profile = null,

pub const Containers = @import("Containers.zig");
pub const Logo = @import("Logo.zig");
pub const Mod = @import("Mod.zig");
pub const Profile = @import("Profile.zig");

/// Colors and the tab animation from the theme, as `Mod.from` makes them, the logo, and prefs
/// for every profile.
pub fn from(theme: kosm.Theme) App {
    const values: Mod = .from(theme);
    return .{
        .foreground = values.foreground,
        .accent = values.accent,
        .background = values.background,
        .button = values.button,
        .border = values.border,
        .containers = values.containers,
        .hovered = values.hovered,
        .tab_switch = values.tab_switch,
        .compact_sidebar = values.compact_sidebar,
        .logo = .{ .background = values.background.?, .foreground = values.foreground.? },
        .profile = .from(theme),
    };
}

/// Writes the logo, then `profile` with the app's values in the mod wherever the profile's own
/// are null.
pub fn apply(self: App, output: *kosm.Output) !void {
    if (self.logo) |logo| try logo.apply(output);
    var profile = self.profile orelse return;
    profile.mod = try profile.mod.orElse(self.mod(), output.allocator);
    try profile.apply(output);
}

/// The app's values as the mod's.
pub fn mod(self: App) Mod {
    return .{
        .foreground = self.foreground,
        .accent = self.accent,
        .background = self.background,
        .button = self.button,
        .button_hovered = self.button_hovered,
        .border = self.border,
        .containers = self.containers,
        .hovered = self.hovered,
        .tab_switch = self.tab_switch,
        .compact_sidebar = self.compact_sidebar,
        .extra = self.extra,
    };
}

const testing = std.testing;

test "the theme's background alpha reaches the background and the button raised from it, and a set color wins" {
    const palette: kosm.Palette = .{ .black = kosm.hex("041c26"), .white = kosm.hex("a3c5cc") };
    var theme = kosm.Theme.from(.{ .palette = palette, .mode = .dark });
    try testing.expectEqual(1, from(theme).background.?.alpha);

    theme.background_alpha = 0.5;
    var app = from(theme);
    try testing.expectEqualStrings("#041c2680", app.background.?.hex8().slice());
    try testing.expectEqual(0.5, app.button.?.alpha);
    try testing.expectEqual(1, app.foreground.?.alpha);
    app.background = kosm.hex("000000");
    try testing.expectEqual(1, app.mod().background.?.alpha);
}
