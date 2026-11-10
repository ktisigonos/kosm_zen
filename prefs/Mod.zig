//! `mod.*`: the prefs of Zen mods, which keep their settings in about:config like Zen itself.
//! A mod that is not installed ignores its prefs.

/// `mod.sameerasw.*`: the Transparent Zen mod.
sameerasw: Sameerasw = .{},

pub const Sameerasw = @import("mod/Sameerasw.zig");
