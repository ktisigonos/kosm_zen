//! Zen's about:config prefs and the kosm mod for a set of profiles: the prefs, the mod's values
//! among them, go to each one's `user.js`, which Zen reads at startup, and the mod into its
//! `chrome/zen-themes/kosm`. An app of its own: put a second one in the tree to give some
//! profiles other prefs, and narrow the first one with `exclude`.

const Profile = @This();

const std = @import("std");
const kosm = @import("kosm");
const user_js = @import("user_js.zig");

/// The profile directories to write, a glob. Only directories holding a `prefs.js` count,
/// so `Crash Reports` and the like are skipped. Default: every Zen profile, `~/.zen/*`.
profiles: []const u8 = "~/.zen/*",
/// Profile directories to leave out, globs written like `profiles` (`~/.zen/*.work`).
exclude: []const []const u8 = &.{},
/// Who owns each `user.js`. Default: `default_target`.
target: Target = default_target,
/// How values are spelled. Null fields take the `userjs` adapter's: `#rrggbb`. A null color
/// format becomes `#rrggbbaa` while the page background or a color of `mod` is not opaque, so
/// its alpha is kept.
format: kosm.Format = .{},
/// The prefs to write, named like about:config (`prefs.zen.theme.accent_color`). Null prefs are
/// not written; with none set, no profile is looked for or written.
prefs: Prefs = .{},
/// The kosm mod's values. With none set, no mod is written. Default: none; `App` fills the
/// null ones of its own profile from its fields, and `Mod.from(theme)` gives a second profile
/// set the same.
mod: Mod = .{},
/// Prefs the app doesn't cover, written after its own, each named by its whole
/// about:config name: `.{ .path = "zen.urlbar.behavior", .value = .{ .string = "float" } }`. A
/// name a set pref or another extra already has fails the apply. Default: none.
extra: []const kosm.Setting = &.{},

/// Zen's about:config prefs.
pub const Prefs = @import("Prefs.zig");
/// The kosm mod.
pub const Mod = @import("Mod.zig");

/// Who owns a profile's `user.js`.
pub const Target = enum {
    /// A `// kosm:begin zen` block; the user's own prefs around it are kept. A missing or empty
    /// `user.js` is created holding only the block.
    block,
    /// The whole file, so kosm is its source of truth.
    generate,
};

/// The target every profile starts with. Change it here to make owning the whole file the default.
pub const default_target: Target = .block;

/// The id of the block kosm owns in `user.js`.
const block_id = "zen";

/// Prefs from the theme: the accent from the accent role, the window scheme from the mode,
/// page colors from the background and foreground roles, the page background at the theme's
/// `background_alpha`. Every other pref is left to Zen, and the mod is empty.
pub fn from(theme: kosm.Theme) Profile {
    var prefs: Prefs = .{};
    prefs.zen.theme.accent_color = theme.roles.accent;
    prefs.zen.view.window.scheme = if (theme.mode == .dark) .dark else .light;
    prefs.browser.display.background_color = theme.asBackground(theme.roles.background);
    prefs.browser.display.foreground_color = theme.roles.foreground;
    return .{ .prefs = prefs };
}

/// Writes the set prefs, the mod's, then the extras, to the `user.js` of every picked profile,
/// and the mod into each when it has a value.
pub fn apply(given: Profile, output: *kosm.Output) !void {
    const self = given.withDerived();
    const files = try std.mem.concat(output.allocator, u8, &.{ std.mem.trimEnd(u8, self.profiles, "/"), "/user.js" });
    const writes_mod = !self.mod.isEmpty();
    const mod_prefs = if (writes_mod) try self.mod.prefs(output, files) else &.{};
    const mod_extras = try self.mod.extraPrefs(output.allocator);
    const prefs = try self.withExtras(output, files, mod_prefs, mod_extras);
    if (prefs.table.len == 0) return;
    const exclude = try output.allocator.alloc([]const u8, self.exclude.len);
    for (self.exclude, exclude) |directory, *file| file.* = try prefsFile(output.allocator, directory);
    const found = try output.find(.{ .files = try prefsFile(output.allocator, self.profiles), .exclude = exclude });
    for (found) |prefs_js| {
        const file = try std.mem.concat(output.allocator, u8, &.{ std.Io.Dir.path.dirname(prefs_js).?, "/user.js" });
        switch (self.target) {
            .block => try output.block(.{ .file = file, .id = block_id, .lang = "userjs", .format = self.format }, prefs),
            .generate => try output.generate(.{ .file = file, .lang = "userjs", .format = self.format }, prefs),
        }
        if (writes_mod) try Mod.write(output, std.Io.Dir.path.dirname(prefs_js).?, mod_prefs, mod_extras);
    }
}

/// The profile with what follows the page background's alpha, wherever it is null: the prefs
/// that let the window be seen through, on only while it is not opaque, and a color format that
/// keeps alpha while it or a color of the mod is not opaque. Written for an opaque background
/// too, so a translucent kosmos applied before leaves nothing behind.
fn withDerived(self: Profile) Profile {
    var profile = self;
    if (self.mod.hasTranslucentColor() and profile.format.color == null) profile.format.color = .hex8;
    const background = self.prefs.browser.display.background_color orelse return profile;
    const translucent = background.alpha < 1;
    const prefs = &profile.prefs;
    if (prefs.browser.tabs.allow_transparent_browser == null) prefs.browser.tabs.allow_transparent_browser = translucent;
    if (prefs.zen.widget.linux.transparency == null) prefs.zen.widget.linux.transparency = translucent;
    if (translucent and profile.format.color == null) profile.format.color = .hex8;
    return profile;
}

/// The set prefs, the mod's own, then the mod's extras and the profile's, checked so no name is
/// written twice. `files` names the `user.js` files, for errors.
fn withExtras(self: Profile, output: *kosm.Output, files: []const u8, mod_prefs: []const kosm.Setting.Keyed, mod_extras: []const kosm.Setting) !kosm.Value {
    const own = (try user_js.table(output.allocator, self.prefs)).table;
    var prefs: std.ArrayList(kosm.Setting.Keyed) = .empty;
    for (own) |pref| try prefs.append(output.allocator, .{ .path = pref.key, .keys = try output.allocator.dupe(?[]const u8, &.{pref.key}), .value = pref.value });
    try prefs.appendSlice(output.allocator, mod_prefs);
    const extras = try std.mem.concat(output.allocator, kosm.Setting, &.{ mod_extras, self.extra });
    const all = try kosm.Setting.withExtras(output, files, prefs.items, extras, .{ .paths = .whole_name });
    return kosm.Setting.tree(output.allocator, all);
}

/// The `prefs.js` Firefox keeps in every profile directory `directories` picks.
fn prefsFile(allocator: std.mem.Allocator, directories: []const u8) std.mem.Allocator.Error![]const u8 {
    return std.mem.concat(allocator, u8, &.{ std.mem.trimEnd(u8, directories, "/"), "/prefs.js" });
}

const testing = std.testing;
const App = @import("App.zig");
const userjs = @import("kosm_userjs");
const css = @import("kosm_css");
const json = @import("kosm_json");

const Fixture = struct {
    tmp: testing.TmpDir,
    arena: std.heap.ArenaAllocator,
    plan: kosm.Plan,
    diagnostics: kosm.Diagnostics = .{},
    warnings: kosm.Warnings = undefined,
    home_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined,
    output: kosm.Output = undefined,

    fn init(fixture: *Fixture, files: []const [2][]const u8) !void {
        fixture.* = .{ .tmp = testing.tmpDir(.{}), .arena = .init(testing.allocator), .plan = .init(testing.allocator, testing.io) };
        for (files) |file| {
            try fixture.tmp.dir.createDirPath(testing.io, std.Io.Dir.path.dirname(file[0]).?);
            try fixture.tmp.dir.writeFile(testing.io, .{ .sub_path = file[0], .data = file[1] });
        }
        fixture.warnings = .init(fixture.arena.allocator());
        const length = try fixture.tmp.dir.realPath(testing.io, &fixture.home_buffer);
        fixture.output = .{
            .allocator = fixture.arena.allocator(),
            .home = fixture.home_buffer[0..length],
            .adapters = &.{ userjs.adapter, css.adapter, json.adapter },
            .plan = &fixture.plan,
            .diagnostics = &fixture.diagnostics,
            .warnings = &fixture.warnings,
            .app = "zen.profile",
        };
    }

    fn deinit(fixture: *Fixture) void {
        fixture.plan.deinit();
        fixture.arena.deinit();
        fixture.tmp.cleanup();
    }

    /// The planned contents of the file at `path` under the home directory.
    fn planned(fixture: *Fixture, path: []const u8) ![]const u8 {
        const absolute = try std.Io.Dir.path.join(fixture.arena.allocator(), &.{ fixture.output.home, path });
        for (fixture.plan.files.items) |file| {
            if (std.mem.eql(u8, file.path, absolute)) return file.new;
        }
        return error.NotPlanned;
    }
};

const test_profiles = [_][2][]const u8{
    .{ ".zen/a.default/prefs.js", "" },
    .{ ".zen/a.default/user.js", "user_pref(\"browser.startup.page\", 3);\n" },
    .{ ".zen/b.work/prefs.js", "" },
    .{ ".zen/c.empty/prefs.js", "" },
    .{ ".zen/c.empty/user.js", "" },
    .{ ".zen/Crash Reports/events/x", "" },
};

const test_theme = kosm.Theme.from(.{ .palette = .{ .black = kosm.hex("041c26"), .white = kosm.hex("a3c5cc"), .cyan = kosm.hex("268078") }, .mode = .dark });

const expected_block =
    \\// kosm:begin zen
    \\user_pref("zen.theme.accent-color", "#268078");
    \\user_pref("zen.view.window.scheme", 0);
    \\user_pref("zen.widget.linux.transparency", false);
    \\user_pref("browser.display.background_color", "#041c26");
    \\user_pref("browser.display.foreground_color", "#a3c5cc");
    \\user_pref("browser.tabs.allow_transparent_browser", false);
    \\// kosm:end
    \\
;

test "every profile gets a block of prefs, keeping the user's own, and a missing or empty user.js holds only the block" {
    var fixture: Fixture = undefined;
    try fixture.init(&test_profiles);
    defer fixture.deinit();
    try from(test_theme).apply(&fixture.output);

    try testing.expectEqual(3, fixture.plan.files.items.len);
    try testing.expectEqualStrings("user_pref(\"browser.startup.page\", 3);\n" ++ expected_block, try fixture.planned(".zen/a.default/user.js"));
    try testing.expectEqualStrings(expected_block, try fixture.planned(".zen/b.work/user.js"));
    try testing.expectEqualStrings(expected_block, try fixture.planned(".zen/c.empty/user.js"));
}

test "a second profile set gives other prefs to the profiles the first excludes" {
    var fixture: Fixture = undefined;
    try fixture.init(&test_profiles);
    defer fixture.deinit();
    var everyday = from(test_theme);
    everyday.exclude = &.{"~/.zen/*.work"};
    var work = from(test_theme);
    work.profiles = "~/.zen/*.work/";
    work.prefs.zen.view.window.scheme = .light;
    work.prefs.zen.view.compact.enable_at_startup = true;
    try everyday.apply(&fixture.output);
    try work.apply(&fixture.output);

    try testing.expectEqual(3, fixture.plan.files.items.len);
    try testing.expectEqualStrings(expected_block, try fixture.planned(".zen/c.empty/user.js"));
    const work_file = try fixture.planned(".zen/b.work/user.js");
    try testing.expect(std.mem.indexOf(u8, work_file, "user_pref(\"zen.view.window.scheme\", 1);\nuser_pref(\"zen.view.compact.enable-at-startup\", true);\n") != null);
}

test "two profile sets reaching one profile fail the apply" {
    var fixture: Fixture = undefined;
    try fixture.init(&test_profiles);
    defer fixture.deinit();
    var work = from(test_theme);
    work.profiles = "~/.zen/*.work";
    try from(test_theme).apply(&fixture.output);
    try testing.expectError(error.EditsOverlap, work.apply(&fixture.output));
    try testing.expectEqualStrings("~/.zen/b.work/user.js", fixture.diagnostics.file);
}

test "the generate target owns the whole user.js" {
    var fixture: Fixture = undefined;
    try fixture.init(&test_profiles);
    defer fixture.deinit();
    var profile = from(test_theme);
    profile.profiles = "~/.zen/a.default";
    profile.target = .generate;
    profile.prefs = .{};
    profile.prefs.zen.theme.content_element_separation = 0;
    try profile.apply(&fixture.output);
    try testing.expectEqualStrings("user_pref(\"zen.theme.content-element-separation\", 0);\n", try fixture.planned(".zen/a.default/user.js"));
}

test "no profile to write is an error naming the glob" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{.{ ".zen/Crash Reports/events/x", "" }});
    defer fixture.deinit();
    try testing.expectError(error.NoFile, from(test_theme).apply(&fixture.output));
    try testing.expectEqualStrings("~/.zen/*/prefs.js", fixture.diagnostics.file);
}

test "Profile{} sets no prefs, so it looks for no profile and plans nothing" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{});
    defer fixture.deinit();
    const empty: Profile = .{};
    try empty.apply(&fixture.output);
    try testing.expectEqual(0, fixture.plan.files.items.len);
}

test "extras follow the prefs under their whole names, and a name set twice fails naming both" {
    var fixture: Fixture = undefined;
    try fixture.init(&test_profiles);
    defer fixture.deinit();
    var profile: Profile = .{ .profiles = "~/.zen/b.work", .target = .generate };
    profile.prefs.zen.theme.gradient.value = false;
    profile.extra = &.{
        .{ .path = "zen.theme.gradient.show-custom-colors", .value = .{ .boolean = true } },
        .{ .path = "zen.urlbar.behavior", .value = .{ .string = "float" } },
    };
    try profile.apply(&fixture.output);
    try testing.expectEqualStrings(
        \\user_pref("zen.theme.gradient", false);
        \\user_pref("zen.theme.gradient.show-custom-colors", true);
        \\user_pref("zen.urlbar.behavior", "float");
        \\
    , try fixture.planned(".zen/b.work/user.js"));

    profile.extra = &.{.{ .path = "zen.theme.gradient", .value = .{ .boolean = true } }};
    try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
    try testing.expectEqualStrings("extra 'zen.theme.gradient' and setting 'zen.theme.gradient' write the same key, or one inside the other; keep one", fixture.diagnostics.message());
    try testing.expectEqualStrings("~/.zen/b.work/user.js", fixture.diagnostics.file);
}

test "a page background that is not opaque turns on transparency and alpha in colors; set prefs win" {
    var theme = test_theme;
    theme.background_alpha = 0.5;
    {
        var fixture: Fixture = undefined;
        try fixture.init(&.{.{ ".zen/a.default/prefs.js", "" }});
        defer fixture.deinit();
        try from(theme).apply(&fixture.output);
        try testing.expectEqualStrings(
            \\// kosm:begin zen
            \\user_pref("zen.theme.accent-color", "#268078ff");
            \\user_pref("zen.view.window.scheme", 0);
            \\user_pref("zen.widget.linux.transparency", true);
            \\user_pref("browser.display.background_color", "#041c2680");
            \\user_pref("browser.display.foreground_color", "#a3c5ccff");
            \\user_pref("browser.tabs.allow_transparent_browser", true);
            \\// kosm:end
            \\
        , try fixture.planned(".zen/a.default/user.js"));
    }
    {
        var fixture: Fixture = undefined;
        try fixture.init(&.{.{ ".zen/a.default/prefs.js", "" }});
        defer fixture.deinit();
        var profile = from(theme);
        profile.prefs.zen.widget.linux.transparency = false;
        profile.prefs.browser.display.use_document_fonts = .never;
        try profile.apply(&fixture.output);
        const written = try fixture.planned(".zen/a.default/user.js");
        for ([_][]const u8{
            "user_pref(\"zen.widget.linux.transparency\", false);\n",
            "user_pref(\"browser.display.use_document_fonts\", 0);\n",
        }) |expected| try testing.expect(std.mem.find(u8, written, expected) != null);
    }
}

const mod_entry =
    \\{
    \\  "kosm": { "id": "kosm", "name": "Kosm", "preferences": "", "enabled": true }
    \\}
    \\
;

test "a profile with mod values gets them as prefs, the mod's stylesheet and list of string prefs, and its entry's preferences field" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", mod_entry } });
    defer fixture.deinit();
    var profile: Profile = .{ .target = .generate };
    profile.mod.background = kosm.hex("041c2680");
    profile.mod.button = kosm.hex("082e3f");
    profile.mod.hovered = .{ .lightness = 0.1 };
    profile.mod.containers.blue = kosm.hex("4d74af");
    profile.mod.tab_switch = Mod.default_tab_switch;
    profile.mod.extra = &.{.{ .path = "kosm.tab.radius", .value = .{ .raw = "8px" } }};
    try profile.apply(&fixture.output);

    const prefs = try fixture.planned(".zen/a.default/user.js");
    try testing.expect(std.mem.startsWith(u8, prefs,
        \\user_pref("kosm.background-enabled", true);
        \\user_pref("kosm.tab-switch-enabled", true);
        \\user_pref("kosm.background", "#041c2680");
        \\user_pref("kosm.button", "#082e3fff");
        \\user_pref("kosm.button-hovered", "#
    ));
    try testing.expect(std.mem.endsWith(u8, prefs,
        \\user_pref("kosm.containers.blue", "#4d74afff");
        \\user_pref("kosm.tab-switch-duration", "0.25s");
        \\user_pref("kosm.tab-switch-curve", "cubic-bezier(0.175, 0.885, 0.32, 1.35)");
        \\user_pref("kosm.tab.radius", "8px");
        \\
    ));

    const list = try fixture.planned(".zen/a.default/chrome/zen-themes/kosm/preferences.json");
    for ([_][]const u8{ "kosm.background", "kosm.button-hovered", "kosm.containers.blue", "kosm.tab-switch-curve", "kosm.tab.radius" }) |name| {
        const entry = try std.mem.concat(fixture.arena.allocator(), u8, &.{ "\"property\": \"", name, "\",\n    \"label\": \"", name, "\",\n    \"type\": \"string\"" });
        try testing.expect(std.mem.find(u8, list, entry) != null);
    }
    try testing.expect(std.mem.find(u8, list, "enabled") == null);

    const stylesheet = try fixture.planned(".zen/a.default/chrome/zen-themes/kosm/chrome.css");
    try testing.expect(std.mem.find(u8, stylesheet, "@media -moz-pref(\"kosm.background-enabled\") {") != null);
    try testing.expect(std.mem.find(u8, stylesheet, "@media -moz-pref(\"kosm.tab-switch-enabled\") {") != null);

    try testing.expectEqualStrings(
        \\{
        \\  "kosm": { "id": "kosm", "name": "Kosm", "preferences": "preferences.json", "enabled": true }
        \\}
        \\
    , try fixture.planned(".zen/a.default/zen-themes.json"));
}

test "a mod without a background or tab switch turns those parts off" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", mod_entry } });
    defer fixture.deinit();
    var profile: Profile = .{ .target = .generate };
    profile.mod.accent = kosm.hex("268078");
    try profile.apply(&fixture.output);
    try testing.expectEqualStrings(
        \\user_pref("kosm.background-enabled", false);
        \\user_pref("kosm.tab-switch-enabled", false);
        \\user_pref("kosm.accent", "#268078");
        \\
    , try fixture.planned(".zen/a.default/user.js"));
}

test "a missing mod list or mod entry fails naming the file and what to add" {
    var profile: Profile = .{};
    profile.mod.accent = kosm.hex("268078");
    {
        var fixture: Fixture = undefined;
        try fixture.init(&.{.{ ".zen/a.default/prefs.js", "" }});
        defer fixture.deinit();
        try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
        try testing.expectEqualStrings("~/.zen/a.default/zen-themes.json", fixture.diagnostics.file);
        try testing.expect(std.mem.startsWith(u8, fixture.diagnostics.message(), "does not exist; start Zen once, then add the kosm mod's entry"));
    }
    {
        var fixture: Fixture = undefined;
        try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", "{ \"other\": { \"preferences\": \"x\" } }" } });
        defer fixture.deinit();
        try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
        try testing.expectEqualStrings("~/.zen/a.default/zen-themes.json", fixture.diagnostics.file);
        try testing.expect(std.mem.startsWith(u8, fixture.diagnostics.message(), "has no mod 'kosm'; add the kosm mod's entry"));
    }
    {
        var fixture: Fixture = undefined;
        try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", "{ \"kosm\": { \"id\": \"kosm\" } }" } });
        defer fixture.deinit();
        try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
        try testing.expect(std.mem.startsWith(u8, fixture.diagnostics.message(), "mod 'kosm' has no 'preferences' field"));
    }
}

test "a spring tab switch fails, since CSS has no springs" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", mod_entry } });
    defer fixture.deinit();
    var profile: Profile = .{};
    profile.mod.tab_switch = .{ .duration = 0.3, .curve = .{ .spring = .{ .stiffness = 100, .damping = 10 } } };
    try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
    try testing.expectEqualStrings("~/.zen/*/user.js", fixture.diagnostics.file);
    try testing.expectEqualStrings("tab_switch.curve is a spring, which CSS cannot animate; use a bezier", fixture.diagnostics.message());
}

test "a mod extra named like another pref fails naming both" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", mod_entry } });
    defer fixture.deinit();
    var profile: Profile = .{};
    profile.mod.accent = kosm.hex("268078");
    profile.mod.extra = &.{.{ .path = "kosm.accent", .value = .{ .raw = "red" } }};
    try testing.expectError(error.AppFailed, profile.apply(&fixture.output));
    try testing.expectEqualStrings("extra 'kosm.accent' and setting 'kosm.accent' write the same key, or one inside the other; keep one", fixture.diagnostics.message());
}

test "the app fills its profile's mod where the profile's own values are null" {
    var fixture: Fixture = undefined;
    try fixture.init(&.{ .{ ".zen/a.default/prefs.js", "" }, .{ ".zen/a.default/zen-themes.json", mod_entry } });
    defer fixture.deinit();
    var app: App = .{ .accent = kosm.hex("268078"), .border = kosm.hex("4d74af"), .profile = .{ .target = .generate } };
    app.profile.?.mod.accent = kosm.hex("ff0000");
    try app.apply(&fixture.output);
    const prefs = try fixture.planned(".zen/a.default/user.js");
    try testing.expect(std.mem.find(u8, prefs, "user_pref(\"kosm.accent\", \"#ff0000\");\n") != null);
    try testing.expect(std.mem.find(u8, prefs, "user_pref(\"kosm.border\", \"#4d74af\");\n") != null);

    const no_profile: App = .{ .accent = kosm.hex("268078") };
    const files_before = fixture.plan.files.items.len;
    try no_profile.apply(&fixture.output);
    try testing.expectEqual(files_before, fixture.plan.files.items.len);
}
