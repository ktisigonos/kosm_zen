//! The kosm mod: a Zen mod kosm writes into every profile it reaches, which paints the window,
//! the compact sidebar, the sidebar panel and glance with the kosmos' background and zooms a page
//! in when its tab is selected. Its values are `kosm.*` prefs in `user.js`, which Zen sets as
//! `--kosm-*` properties when it starts, so a change shows after a restart.

const Mod = @This();

const std = @import("std");
const kosm = @import("kosm");

/// Text and icons (`--kosm-foreground`), for your own styles. null: not written.
foreground: ?kosm.Color = null,
/// Links, focused fields and the selected tab's text (`--kosm-accent`), for your own styles.
/// null: not written.
accent: ?kosm.Color = null,
/// The window behind pages, the compact sidebar, the sidebar panel and glance
/// (`--kosm-background`), alpha included. null: not written, and the mod leaves Zen's own
/// background alone.
background: ?kosm.Color = null,
/// Buttons and the toolbar (`--kosm-button`), for your own styles. null: not written.
button: ?kosm.Color = null,
/// Buttons under the pointer (`--kosm-button-hovered`), for your own styles. null: `hovered` of
/// `button` when both are set, else not written.
button_hovered: ?kosm.Color = null,
/// Glance's outline (`--kosm-border`). null: not written; glance keeps a faint white one.
border: ?kosm.Color = null,
/// Container tab colors (`--kosm-containers-blue`, ...), for your own styles. null ones are not
/// written.
containers: Containers = .{},
/// Makes `button_hovered` from `button` when it is null. null: nothing derived.
hovered: ?kosm.Modifier = null,
/// How a page zooms in when its tab is selected. null: it doesn't.
tab_switch: ?TabSwitch = null,
/// The floating sidebar of compact mode: what fills it, and its width while it is x-ray. null:
/// Zen's own, the page showing through.
compact_sidebar: ?CompactSidebar = null,
/// Properties the mod doesn't cover, each a pref named by `path` whose value Zen sets as the
/// property of that name with `.` as `-`: `.{ .path = "kosm.tab.radius", .value = .{ .raw = "8px" } }`
/// is `--kosm-tab-radius`. Values are written as text. Default: none.
extra: []const kosm.Setting = &.{},

pub const Containers = @import("Containers.zig");

/// A page zooming in from 90% while it fades in.
pub const TabSwitch = struct {
    /// Seconds.
    duration: f64,
    /// How the zoom moves; the fade eases in and out. A bezier: CSS has no springs.
    curve: kosm.Curve,
};

/// The floating sidebar of compact mode.
pub const CompactSidebar = struct {
    /// What is behind the sidebar's tabs. Default: `.none`.
    fill: Fill = .none,
    /// Pixels the sidebar is wide while it is x-ray, which fixes it so the cut-out follows it
    /// exactly; dragging its edge no longer resizes it. Other fills keep Zen's own width.
    /// Default: 400, wide enough for long tab titles.
    width: f64 = 400,

    pub const Fill = enum {
        /// The page shows through the sidebar's background, as Zen draws it.
        none,
        /// The page is cut out beneath the sidebar while it shows, so the sidebar lies over the
        /// window's background and the compositor's blur of what is behind the window. CSS can't
        /// blur the page itself: Firefox draws pages in another process.
        xray,
        /// The sidebar is painted with the background made opaque, so nothing shows through.
        /// Needs `background`.
        solid,
    };
};

/// X-ray while the background is translucent, so the sidebar shows what the window does;
/// over an opaque background Zen's own sidebar.
pub fn defaultCompactSidebar(background: kosm.Color) CompactSidebar {
    return .{ .fill = if (background.alpha < 1) .xray else .none };
}

/// The mod's id in Zen's mod list, `zen-themes.json`, and its folder under `chrome/zen-themes`.
pub const id = "kosm";

/// The field of the mod's entry in `zen-themes.json` kosm sets, so a missing entry fails the
/// apply. Zen reads the mod's preferences only while the entry has it.
const entry_field = "preferences";

/// The prefs that turn the mod's parts on, which its CSS reads by name.
const Switches = struct {
    background_enabled: []const u8 = "kosm.background-enabled",
    tab_switch_enabled: []const u8 = "kosm.tab-switch-enabled",
    compact_sidebar_xray: []const u8 = "kosm.compact-sidebar-xray",
    compact_sidebar_solid: []const u8 = "kosm.compact-sidebar-solid",
};
const switches: Switches = .{};

/// The animation Transparent Zen calls smooth: a slight overshoot.
pub const default_tab_switch: TabSwitch = .{ .duration = 0.25, .curve = .cubicBezier(0.175, 0.885, 0.32, 1.35) };

/// Colors from the theme: the foreground role, the background role at the theme's
/// `background_alpha`, buttons raised from it and hovered by the theme's `state.hovered`, the
/// accent role for the accent and border, the wheel's hues for containers,
/// `default_tab_switch` and `defaultCompactSidebar`.
pub fn from(theme: kosm.Theme) Mod {
    const palette = theme.palette;
    const background = theme.asBackground(theme.roles.background);
    return .{
        .foreground = theme.roles.foreground,
        .accent = theme.roles.accent,
        .background = background,
        .button = theme.variations.surface.raised.apply(background),
        .border = theme.roles.accent,
        .containers = .{
            .blue = palette.blue,
            .turquoise = palette.cyan,
            .green = palette.green,
            .yellow = palette.yellow,
            .orange = palette.orange,
            .red = palette.red,
            .pink = palette.pink,
            .purple = palette.purple,
        },
        .hovered = theme.variations.state.hovered,
        .tab_switch = default_tab_switch,
        .compact_sidebar = defaultCompactSidebar(background),
    };
}

/// Whether nothing is set, so no mod is written.
pub fn isEmpty(self: Mod) bool {
    if (self.tab_switch != null or self.compact_sidebar != null or self.extra.len != 0) return false;
    inline for (color_fields) |name| if (@field(self, name) != null) return false;
    inline for (@typeInfo(Containers).@"struct".field_names) |name| if (@field(self.containers, name) != null) return false;
    return true;
}

/// `self` with every null field taken from `fallback`, and the extras of both, `self`'s first.
pub fn orElse(self: Mod, fallback: Mod, allocator: std.mem.Allocator) std.mem.Allocator.Error!Mod {
    var mod = self;
    inline for (color_fields) |name| if (@field(mod, name) == null) {
        @field(mod, name) = @field(fallback, name);
    };
    inline for (@typeInfo(Containers).@"struct".field_names) |name| if (@field(mod.containers, name) == null) {
        @field(mod.containers, name) = @field(fallback.containers, name);
    };
    if (mod.hovered == null) mod.hovered = fallback.hovered;
    if (mod.tab_switch == null) mod.tab_switch = fallback.tab_switch;
    if (mod.compact_sidebar == null) mod.compact_sidebar = fallback.compact_sidebar;
    mod.extra = try std.mem.concat(allocator, kosm.Setting, &.{ self.extra, fallback.extra });
    return mod;
}

/// Whether a color the mod writes is not opaque, so prefs must keep alpha.
pub fn hasTranslucentColor(self: Mod) bool {
    inline for (color_fields) |name| if (@field(self, name)) |color| if (color.alpha < 1) return true;
    inline for (@typeInfo(Containers).@"struct".field_names) |name| if (@field(self.containers, name)) |color| if (color.alpha < 1) return true;
    return false;
}

const color_fields = .{ "foreground", "accent", "background", "button", "button_hovered", "border" };

/// The mod's own prefs, named by their whole names: the switches the mod's CSS reads, then a
/// string pref per set value. `file` names the files they go to, for errors.
pub fn prefs(self: Mod, output: *kosm.Output, file: []const u8) kosm.Output.Error![]const kosm.Setting.Keyed {
    const allocator = output.allocator;
    var list: std.ArrayList(kosm.Setting.Keyed) = .empty;
    try appendPref(allocator, &list, switches.background_enabled, .{ .boolean = self.background != null });
    try appendPref(allocator, &list, switches.tab_switch_enabled, .{ .boolean = self.tab_switch != null });
    const sidebar = self.compact_sidebar orelse CompactSidebar{};
    if (sidebar.fill == .solid and self.background == null)
        return output.fail(file, "compact_sidebar.fill .solid paints the sidebar with background made opaque, but background is null", .{});
    try appendPref(allocator, &list, switches.compact_sidebar_xray, .{ .boolean = sidebar.fill == .xray });
    try appendPref(allocator, &list, switches.compact_sidebar_solid, .{ .boolean = sidebar.fill == .solid });
    var colors = self;
    if (colors.button_hovered == null) colors.button_hovered = self.derivedButtonHovered();
    inline for (color_fields) |name| if (@field(colors, name)) |color| {
        try appendPref(allocator, &list, "kosm." ++ comptime propertyName(name), .{ .color = color });
    };
    inline for (@typeInfo(Containers).@"struct".field_names) |name| if (@field(self.containers, name)) |color| {
        try appendPref(allocator, &list, "kosm.containers." ++ name, .{ .color = color });
    };
    if (self.tab_switch) |tab_switch| {
        try appendPref(allocator, &list, "kosm.tab-switch-duration", try joined(allocator, &.{ .{ .float = tab_switch.duration }, .{ .raw = "s" } }));
        try appendPref(allocator, &list, "kosm.tab-switch-curve", try curveValue(output, file, tab_switch.curve));
    }
    if (sidebar.fill == .xray) try appendPref(allocator, &list, "kosm.compact-sidebar-width", try pixels(allocator, sidebar.width));
    return list.items;
}

fn derivedButtonHovered(self: Mod) ?kosm.Color {
    const hovered = self.hovered orelse return null;
    const button = self.button orelse return null;
    return hovered.apply(button);
}

/// The extras as prefs, each value written as text so Zen sets it as a property.
pub fn extraPrefs(self: Mod, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const kosm.Setting {
    const extras = try allocator.alloc(kosm.Setting, self.extra.len);
    for (self.extra, extras) |extra, *pref| pref.* = .{ .path = extra.path, .value = try asText(allocator, extra.value) };
    return extras;
}

/// Writes the mod's CSS and its list of string prefs into the profile at `directory`, and
/// checks that the mod is in Zen's mod list there, which only Zen or the user may add it to.
/// `own` and `extras` are the prefs from `prefs` and `extraPrefs`; Zen sets each one that is
/// not a switch as a property.
pub fn write(output: *kosm.Output, directory: []const u8, own: []const kosm.Setting.Keyed, extras: []const kosm.Setting) kosm.Output.Error!void {
    const folder = try std.mem.concat(output.allocator, u8, &.{ directory, "/chrome/zen-themes/", id });
    const stylesheet = try std.mem.concat(output.allocator, u8, &.{ folder, "/chrome.css" });
    try output.template(switches, .{ .file = stylesheet, .text = @embedFile("mod/chrome.css") });

    var entries: std.ArrayList(PreferenceEntry) = .empty;
    for (own) |pref| if (pref.value != .boolean) try entries.append(output.allocator, .{ .property = pref.path, .label = pref.path });
    for (extras) |pref| try entries.append(output.allocator, .{ .property = pref.path, .label = pref.path });
    try output.generate(.{ .file = try std.mem.concat(output.allocator, u8, &.{ folder, "/preferences.json" }), .lang = "json" }, entries.items);

    try checkEntry(output, try std.mem.concat(output.allocator, u8, &.{ directory, "/zen-themes.json" }));
}

/// One pref in a mod's `preferences.json`, as Zen reads it.
const PreferenceEntry = struct {
    property: []const u8,
    label: []const u8,
    type: []const u8 = "string",
};

/// Sets the mod's `preferences` field in `zen-themes.json`, failing with what to add when the
/// file or the mod's entry is missing.
fn checkEntry(output: *kosm.Output, file: []const u8) kosm.Output.Error!void {
    const how = "add the kosm mod's entry to it with Zen closed, as kosm_zen's README shows, so Zen loads the mod";
    var mods = output.edit(.{ .files = file, .lang = "json" }) catch |err| switch (err) {
        error.NoFile => return output.fail(file, "does not exist; start Zen once, then " ++ how, .{}),
        else => return err,
    };
    if ((try mods.nodes(id)).len == 0) return output.fail(file, "has no mod '" ++ id ++ "'; " ++ how, .{});
    mods.set(id ++ "." ++ entry_field, entry_field ++ ".json") catch |err| switch (err) {
        error.NoMatch => return output.fail(file, "mod '" ++ id ++ "' has no '" ++ entry_field ++ "' field; " ++ how, .{}),
        else => return err,
    };
}

fn appendPref(allocator: std.mem.Allocator, list: *std.ArrayList(kosm.Setting.Keyed), name: []const u8, value: kosm.Value) std.mem.Allocator.Error!void {
    try list.append(allocator, .{ .path = name, .keys = try allocator.dupe(?[]const u8, &.{name}), .value = value });
}

fn joined(allocator: std.mem.Allocator, parts: []const kosm.Value) std.mem.Allocator.Error!kosm.Value {
    return .{ .joined = try allocator.dupe(kosm.Value, parts) };
}

fn pixels(allocator: std.mem.Allocator, amount: f64) std.mem.Allocator.Error!kosm.Value {
    return joined(allocator, &.{ .{ .float = amount }, .{ .raw = "px" } });
}

/// `value` as text: the userjs adapter writes a joined value as a string.
fn asText(allocator: std.mem.Allocator, value: kosm.Value) std.mem.Allocator.Error!kosm.Value {
    return switch (value) {
        .string => value,
        else => joined(allocator, &.{value}),
    };
}

/// CSS's `cubic-bezier(x1, y1, x2, y2)`.
fn curveValue(output: *kosm.Output, file: []const u8, curve: kosm.Curve) kosm.Output.Error!kosm.Value {
    const bezier = switch (curve) {
        .bezier => |bezier| bezier,
        .spring => return output.fail(file, "tab_switch.curve is a spring, which CSS cannot animate; use a bezier", .{}),
    };
    return joined(output.allocator, &.{
        .{ .raw = "cubic-bezier(" }, .{ .float = bezier.x1 },
        .{ .raw = ", " },            .{ .float = bezier.y1 },
        .{ .raw = ", " },            .{ .float = bezier.x2 },
        .{ .raw = ", " },            .{ .float = bezier.y2 },
        .{ .raw = ")" },
    });
}

/// A field's pref and property name: `button_hovered` is `button-hovered`.
fn propertyName(comptime field_name: []const u8) []const u8 {
    comptime {
        var name: [field_name.len]u8 = field_name[0..].*;
        std.mem.replaceScalar(u8, &name, '_', '-');
        const final = name;
        return &final;
    }
}
