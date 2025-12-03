# Changelog

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
