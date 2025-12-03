# Changelog

## [3] – Unreleased

### Added

- Exposed `GetLayouts()` API returning `{ index, name, layoutType, isActive }` with Modern/Classic populated from Blizzard globals when available.
- Added layout name to `layoutadded` and `layoutduplicate` callbacks (duplicate passes the new name once).
- Added cached layout name to `layoutdeleted` callbacks so consumers can show the deleted layout’s name.
- `internal:RefreshSettingValues` now accepts an optional list of setting rows to refresh selectively.

### Changed

- `layoutrenamed` callback now uses the UI index (custom layouts offset by +2) for consistency with other layout callbacks.
- Default Modern/Classic names now pull from `LAYOUT_STYLE_MODERN` / `LAYOUT_STYLE_CLASSIC` when available.

### Fixed

- Layout delete flow now caches removed layout names even when multiple `EDIT_MODE_LAYOUTS_UPDATED` events fire before the delete callback, preventing missing/empty names.
- Protected `SetPropagateKeyboardInput` now only runs when Edit Mode is open and not in combat, avoiding `ADDON_ACTION_BLOCKED` during login/combat and preventing key capture outside Edit Mode.
- Slider `set` handlers no longer fire when the value is unchanged, reducing redundant updates on drags.
- Re-clicking an already selected frame no longer rebuilds settings/getters; selection clicks are ignored unless picking from an overlap menu.

## [2] – 2025-12-02

### Added

- SettingsMode now requires a unique prefix (`SetVariablePrefix`) and supports per-control `prefix`/`variable` to avoid cross-addon collisions.
- Per-prefix “New” badge resolver (`SetNewTagResolverForPrefix`) with prefixed `newTagID` support on categories; legacy default resolver removed.
- MultiDropdown refactored to be data-driven (no addon.db coupling), supports `getSelection`/`setSelection` or `isSelected`/`setSelected`, custom summaries, and summary hiding.
- Notify hooks (`notify`/`AttachNotify`) now available on all Settings controls and auto-prefix their tags.
- Sound dropdown defaults no longer require a global localization table; other dropdowns and sliders retain existing behaviors.
- Edit Mode: added overlap chooser menu when multiple registered frames sit under the cursor (pick target on click).
- Option to disable the drag feature per condition and per API call
- Option to hide visibility of EditMode overlay per Frame with an icon
  - can be disabled/enabled by api or default values
- Updated dropdowns to modern style

### Changed

- Prefix enforcement: prefix can only be set once; `newTagID` and notify tags are auto-prefixed; “New” badges only evaluate for lib-registered categories/controls.

## [1] – 2025-11-30

First Upload
