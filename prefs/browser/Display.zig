//! Firefox's `browser.display.*` prefs.

const kosm = @import("kosm");

/// `background_color`: page background where a page sets none. Default: black, white in light
/// mode, at the theme's `background_alpha`.
background_color: ?kosm.Color = null,
/// `foreground_color`: page text where a page sets none. Default: white, black in light mode.
foreground_color: ?kosm.Color = null,

/// `use_document_fonts`: whether pages may pick their own fonts. `.never` shows every page in
/// your fonts, as fontconfig's `sans-serif`, `serif` and `monospace` resolve them. null:
/// Firefox's, `.allowed`.
use_document_fonts: ?DocumentFonts = null,

/// Firefox's `browser.display.use_document_fonts` values.
pub const DocumentFonts = enum(u1) {
    never = 0,
    allowed = 1,
};

/// Pref names that differ from the field names' `_` -> `-` spelling.
pub const pref_names = .{ .background_color = "background_color", .foreground_color = "foreground_color", .use_document_fonts = "use_document_fonts" };
