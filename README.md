# kosm_zen

Zen Browser for kosm: its colors and tab animation through the kosm mod, a Zen mod kosm writes
into every profile, and its about:config prefs in every profile's `user.js`. The adapters of
`kosm_css`, `kosm_json` and `kosm_userjs` write the files; this package brings them along
(`kosm_zen.css_adapter`, `kosm_zen.json_adapter`, `kosm_zen.userjs_adapter`).

## The kosm mod

The mod paints the window behind pages, the floating sidebar of compact mode, the sidebar panel
and glance with the kosmos' background, alpha included, and zooms a page in when its tab is
selected. It replaces the Transparent Zen mod. Its values are prefs (`kosm.background`, ...)
in the `user.js` block below, which Zen sets as custom properties (`--kosm-background`, ...)
when it starts, so your own `userChrome.css` can use them too, with no `@import`:

```css
.identity-color-blue {
  --identity-tab-color: var(--kosm-containers-blue) !important;
}
```

kosm writes the mod to `chrome/zen-themes/kosm/` in each profile, but only Zen and you add mods
to Zen's list of mods. Once per profile, with Zen closed, add this entry to the profile's
`zen-themes.json` (start Zen once first if the file is missing), inside its outer `{ }`, with a
comma after the entry before it:

```json
"kosm": {
  "id": "kosm",
  "name": "Kosm",
  "description": "The kosmos' colors and tab animation, written by kosm.",
  "author": "kosm",
  "version": "1.0.0",
  "preferences": "preferences.json",
  "enabled": true
}
```

kosm keeps the entry's `preferences` field set (Zen reads the mod's prefs only while it is),
so an apply fails naming the file when the entry is missing. Zen's mod updater leaves the mod
alone: the mod store doesn't know it.

A change shows after Zen restarts. Toggling the mod in Zen's settings doesn't reread
`user.js`; it is needed only when a new kosm_zen changes the mod's stylesheet, which Zen
reloads only then (or when Zen itself updates).

### Moving from `kosm.css` and Transparent Zen

1. Remove `@import url("kosm.css");` from your `userChrome.css` and `userContent.css`, and
   delete `~/.config/ZenBrowser/kosm.css`; the `--kosm-*` properties now come from the mod in
   the browser's own UI. Pages such as the new tab page don't see them.
2. Remove the Transparent Zen mod in Zen's settings; the kosm mod does its background, tab
   animation, transparent sidebar panel, glance and page tint.
3. `toolkit.legacyUserProfileCustomizations.stylesheets` is no longer set; set
   `prefs.toolkit.legacy_user_profile_customizations.stylesheets = true` yourself while you
   keep a `userChrome.css`.
4. Apply, add the mod's entry as above, and restart Zen.

## Fields

| Field | Property | Default |
|---|---|---|
| `foreground` | `--kosm-foreground` | null; `from`: the theme's foreground role |
| `accent` | `--kosm-accent` | null; `from`: the theme's accent role |
| `background` | `--kosm-background` | null: Zen keeps its own background; `from`: the theme's background role at its `background_alpha`. Paints the window, compact sidebar, sidebar panel and glance |
| `button` | `--kosm-button` | null; `from`: `surface.raised` of `background` |
| `button_hovered` | `--kosm-button-hovered` | null: `hovered` of `button` when both are set |
| `border` | `--kosm-border` | null: glance keeps a faint white outline; `from`: the theme's accent role. Glance's outline |
| `containers.blue` | `--kosm-containers-blue` | null; `from`: the wheel's blue |
| `containers.turquoise` | `--kosm-containers-turquoise` | null; `from`: the wheel's cyan |
| `containers.green` | `--kosm-containers-green` | null; `from`: the wheel's green |
| `containers.yellow` | `--kosm-containers-yellow` | null; `from`: the wheel's yellow |
| `containers.orange` | `--kosm-containers-orange` | null; `from`: the wheel's orange |
| `containers.red` | `--kosm-containers-red` | null; `from`: the wheel's red |
| `containers.pink` | `--kosm-containers-pink` | null; `from`: the wheel's pink |
| `containers.purple` | `--kosm-containers-purple` | null; `from`: the wheel's purple |
| `hovered` | | null: nothing derived; `from`: the theme's `state.hovered` |
| `tab_switch` | `--kosm-tab-switch-duration`, `--kosm-tab-switch-curve` | null: no animation; `from`: `Mod.default_tab_switch`, 0.25 s on `cubic-bezier(0.175, 0.885, 0.32, 1.35)`. `.duration` in seconds, `.curve` a `kosm.Curve` bezier (a spring fails the apply) for the zoom from 90%; the fade eases in and out |
| `logo` | | null: not written; `from`: Zen's logo at `~/.config/ZenBrowser/ZenLogo.svg` (`file`, `format`, `background`, `foreground`), for a user style to show, e.g. on the new tab page |
| `profile` | | null: only the logo is written; `from`: `Profile.from(theme)` |
| `extra` | | `&.{}`: properties the app doesn't cover, by pref name |

A null color is not written. The app's values go to `profile`'s mod wherever the profile's
own (`profile.mod`) are null, so `kosm_zen.App{ .profile = .{} }` writes only what you assign
(`.{ .accent = kosm.hex("268078"), .profile = .{} }`).

`extra` writes other prefs the mod sets as properties, each named by its whole pref name, its
value written as text: `.{ .path = "kosm.tab.radius", .value = .{ .raw = "8px" } }` is
`--kosm-tab-radius`. A name another pref has fails the apply naming both.

## Prefs

Zen reads a profile's `user.js` at startup, so a pref kosm writes takes effect the next time Zen
starts. `profile` writes its prefs to every profile directory under `~/.zen` (every one holding a
`prefs.js`) inside a block, keeping any prefs of your own in the file:

```js
user_pref("browser.startup.page", 3);
// kosm:begin zen
user_pref("zen.theme.accent-color", "#268078");
...
// kosm:end
```

A missing or empty `user.js` is created holding only the block. `target = .generate` makes kosm
own the whole file instead.

To give some profiles other prefs, put a second `kosm_zen.Profile` in your kosmos' tree and
narrow the first one. Two profile sets that reach the same profile fail the apply. A second
profile set gets the mod only through its own `mod`:

```zig
result.zen.profile.?.exclude = &.{"~/.zen/*.work"};
result.zen_work = kosm_zen.Profile.from(theme);
result.zen_work.mod = kosm_zen.Mod.from(theme);
result.zen_work.profiles = "~/.zen/*.work";
result.zen_work.prefs.zen.view.window.scheme = .light;
```

On a machine without Zen, set `profile = null` (a profile glob matching nothing fails the apply).

### `Profile` fields

| Field | Default |
|---|---|
| `profiles` | `~/.zen/*`: a glob of profile directories; only ones holding a `prefs.js` count |
| `exclude` | none: globs of profile directories to leave out |
| `target` | `.block` (`default_target`); `.generate` owns the whole `user.js` |
| `format` | `.{}`: the `userjs` adapter's `#rrggbb`, `#rrggbbaa` while the page background or a mod color is not opaque |
| `prefs` | `.{}`, below; with no pref and no mod value set, the profile writes nothing and needs no Zen |
| `mod` | `.{}`: no mod; the app fills its own profile's from its fields. `kosm_zen.Mod.from(theme)` gives the app's defaults. Its fields are the app's color fields, `hovered`, `tab_switch` and `extra` |
| `extra` | `&.{}`: prefs the app doesn't cover, by their whole about:config name |

`extra` writes prefs `prefs` doesn't cover, after its own, each named by its whole about:config
name (no quotes needed): `.{ .path = "zen.urlbar.behavior", .value = .{ .string = "float" } }`.
Prefs never nest, so only a name written twice, by `prefs` or another extra, fails the apply.

### `prefs` fields

Named like about:config: `prefs.zen.theme.accent_color` is `zen.theme.accent-color`. A null pref
is not written, so Zen's own value stays. A pref that also has prefs below it is a group, and
its own value is the group's `value` field: `prefs.zen.theme.gradient.value` is
`zen.theme.gradient`.

| Field | Pref | Default |
|---|---|---|
| `zen.theme.accent_color` | `zen.theme.accent-color` | cyan |
| `zen.theme.gradient.value` | `zen.theme.gradient` | null (Zen: true) |
| `zen.theme.content_element_separation` | `zen.theme.content-element-separation` (px) | null (Zen: 8) |
| `zen.theme.border_radius` | `zen.theme.border-radius` (px, -1: the platform's) | null (Zen: -1) |
| `zen.theme.hide_tab_throbber` | `zen.theme.hide-tab-throbber` | null (Zen: true) |
| `zen.theme.use_system_colors` | `zen.theme.use-system-colors` | null (Zen: false) |
| `zen.view.window.scheme` | `zen.view.window.scheme` (`.dark`, `.light`, `.auto`) | the theme's mode |
| `zen.view.compact.enable_at_startup` | `zen.view.compact.enable-at-startup` | null (Zen: false) |
| `zen.view.compact.hide_tabbar` | `zen.view.compact.hide-tabbar` | null (Zen: true) |
| `zen.view.compact.hide_toolbar` | `zen.view.compact.hide-toolbar` | null (Zen: false) |
| `zen.view.grey_out_inactive_windows` | `zen.view.grey-out-inactive-windows` | null (Zen: true) |
| `zen.view.use_single_toolbar` | `zen.view.use-single-toolbar` | null (Zen: true) |
| `zen.view.show_newtab_button_top` | `zen.view.show-newtab-button-top` | null (Zen: true) |
| `zen.view.sidebar_expanded` | `zen.view.sidebar-expanded` | null (Zen: true) |
| `zen.widget.linux.transparency` | `zen.widget.linux.transparency` | null: true while the page background is not opaque, false while it is (Zen: false) |
| `browser.display.background_color` | `browser.display.background_color` | black, white in light mode, at the theme's `background_alpha` |
| `browser.display.foreground_color` | `browser.display.foreground_color` | white, black in light mode |
| `browser.display.use_document_fonts` | `browser.display.use_document_fonts` (`.never`, `.allowed`) | null (Firefox: `.allowed`); `.never` shows every page in your fontconfig fonts |
| `browser.tabs.allow_transparent_browser` | `browser.tabs.allow_transparent_browser` | null: true while the page background is not opaque, false while it is (Firefox: false) |
| `toolkit.legacy_user_profile_customizations.stylesheets` | `toolkit.legacyUserProfileCustomizations.stylesheets` | null (Firefox: false); true makes Zen read `userChrome.css` and `userContent.css` |
