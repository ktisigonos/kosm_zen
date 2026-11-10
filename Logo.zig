//! Zen's logo in the theme's colors, as an SVG file a user style shows, such as the new tab
//! page's `background: url("ZenLogo.svg")` in userContent.css.

const kosm = @import("kosm");

/// The SVG file kosm owns. Default: `~/.config/ZenBrowser/ZenLogo.svg`.
file: []const u8 = "~/.config/ZenBrowser/ZenLogo.svg",
/// How colors are spelled. Default: `#rrggbbaa`, so a translucent background stays so.
format: kosm.Format = .{ .color = .hex8 },
/// The rounded square behind the rings, and the gap between them.
background: kosm.Color,
/// The rings.
foreground: kosm.Color,

/// Writes the logo whole.
pub fn apply(self: @This(), output: *kosm.Output) !void {
    try output.template(self, .{ .file = self.file, .text = @embedFile("logo.svg"), .format = self.format });
}
