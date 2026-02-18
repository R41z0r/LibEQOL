# Changelog

## [17] - 2026-02-09

Optimized:

- EditMode: Reduced repeated `C_EditMode.GetLayouts()` calls by caching lazy `layoutNames` lookups and syncing cache entries from layout snapshots.
- EditMode: Switched specialization listener to `RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")` to avoid unnecessary non-player event handling.

## [16] - 2026-02-08

Fixed:

- Wrong parent template

## [15] - 2026-01-26

Added:

- EditMode: Manager toggle panel under EditModeManagerFrame (scrollable, two-column layout, categories, sorting, and eye toggle to hide overlays).
- EditMode: Manager category API (`AddManagerCategory`) and toggle API (`AddManagerToggle`/`AddManagerCheckbox`).
- EditMode: New Input setting row (plain text/number, readOnly, maxChars, inputWidth, formatter).
- EditMode: Listen for `EditModeExternal.hideDialog` to close dialogs/selections for addon compatibility.
- Settings: New Input control (`CreateInput`) with single-line + multiline support, readOnly, placeholder, and width/height options.
- Settings: XML templates for Color Overrides (`_ColorSwatchTemplate`, `_ColorOverrideTemplate`).

## [14] - 2026-01-24

Fixed:

- EditMode: Dividers now appear correctly on first expand; refresh applies to rows without `SetEnabled`.
- EditMode: Prevented settings row width from shrinking after repeated resets (dropdowns/sliders stay aligned).
- EditMode: Settings enable-state cache now updates on rebuild/refresh, avoiding stale `isEnabled` after reset.
- EditMode: `layout` callbacks now fire at least once on init (even when active layout is Modern/Classic).

## [13] - 2026-01-22

Fixed:

- EditMode: Settings row widths now clamp to available space when no scroll bar is visible (dropdowns, multi dropdowns, sliders).
- EditMode: Slider value text stays within the row when input is hidden.
- EditMode: Settings rows reserve scroll bar width even when it is hidden to keep alignment consistent.

## [12] - 2026-01-22

Added:

- EditMode: Optional max height for settings lists with automatic scrolling (`settingsMaxHeight`/`maxSettingsHeight`, `SetFrameSettingsMaxHeight`).
- Docs: Added guidance for settings list max height and the new setter.

Fixed:

- EditMode: Settings dialog layout tweaks for dropdown+color, multi dropdown, and slider input alignment.

## [11] - 2026-01-02

Fixed:

- Settings: Multi Dropdown no longer duplicates when expanding parent sections (avoids re-entrant SyncSetting during init).

## [10] - 2025-12-28

Added:

- EditMode: Per-frame settings layout overrides for row spacing and row heights (slider, dropdown, divider, etc).

Fixed:

- EditMode: Settings refresh is now debounced and avoids redundant layout/enable/visibility updates to improve performance.

## [9] - 2025-12-23

Added:

- Settings: Per-option tooltips for dropdowns (single, scroll, checkbox+dropdown) via option tables (`tooltip`/`desc`/`description`), including forwarded `disabled`/`warning`/`recommend`/`onEnter`.
- Docs: Documented per-option tooltip support for dropdowns.

## [8] - 2025-12-22

Added:

- EditMode: Additional frames included in the manager "eye" hide list (Midnight frames).
- Settings: Category lookup/search helpers (`GetCategoryByID`, `GetCategoryByName`, `FindCategory`).

Fixed:

- Settings: Slider input and formatter bugs; slider updates are now debounced.

## [7] - 2025-12-12

Added:

- Settings: Color Overrides can opt into alpha via `hasOpacity = true`; supports ColorMixin callbacks (`getColorMixin`/`setColorMixin`/`getDefaultColorMixin`) alongside numeric RGB(A).
- Settings: Color Overrides now auto-size based on entry count (no more overlap) and respect `spacing`/`rowHeight`; hover highlight removed to match Blizzard.
- Docs: Settings pages aligned to real APIs (prefix/variable requirement, Color Overrides alpha/mixin example, option defaults).
- Settings: New checkbox+dropdown combined control using Blizzard’s template.
- Settings: New checkbox+slider combined control using Blizzard’s template.
- Settings: New checkbox+button combined control using Blizzard’s template.
- Settings: Buttons can now show a left-hand label (pass `label`/`name`/`textLabel`).
- Settings: New `CreateScrollDropdown` control for scrollable single-select menus (`height`/`menuHeight`).

Fixed:

- Settings: Color Overrides label color pooling no longer leaks between rows; defaults restored on reuse.
- Settings: Multi Dropdown forwards `customText`/`customDefaultText` and `callback` to the mixin again.
- Settings: Multi Dropdown now correctly uses height to show a scrollframe.
- Settings: Color Overrides padding default reduced to zero to avoid extra trailing space; extent respects explicit `basePadding`/`minHeight`/`height`.
- Settings: Multi-dropdown serialization to ignore boolean array entries, preventing table.concat crashes when saved selections are stored as [1]=true, [2]=true,

## [6] - 2025-12-07

Added:

- EditMode: Snap-to-grid/magnetism support with preview; frames expose Blizzard’s magnetism API and snap on drag finish when snapping is enabled.
- Settings: Top-level `order = { ... }` for map-based dropdowns (single, multi, sound) to control option ordering.
- Settings: `defaultSelection` for multi dropdowns so “Reset to default” restores a defined selection (defaults to empty).
- Settings: Color overrides can tint labels via `colorizeLabel`/`colorizeText` (doc’d).
- Settings: Sound dropdown honors disabled state on init and greys out its label when parent checks disable it.

Fixed:

- Multi dropdown `hideSummary` now respected again.
- Rounded position offsets when firing EditMode callbacks to avoid tiny float drift.

## [5] - 2025-12-06

Bugfix:

- Duplicate load of XML templates shared across multiple addons fixed; template names are auto-suffixed via `@project-abbreviated-hash@` in the BigWigs packager to avoid “Deferred XML Node … already exists” when multiple embeds are present
