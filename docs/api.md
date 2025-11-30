# API reference

## Core
- `AddFrame(frame, callback, defaultPosition)` – registers a frame for Edit Mode. `callback(frame, layoutName, point, x, y)` runs on move/reset; positions are relative to `UIParent` and `relativePoint` equals `point`. `defaultPosition` defaults to `{ point = "CENTER", x = 0, y = 0 }` and may include `relativePoint` (treated the same as `point`).
- `GetFrameDefaultPosition(frame)` – returns the default position for a registered frame.
- `SetFrameResetVisible(frame, showReset)` – hide or re-show the automatic "Reset Position" button.

## Settings dialog
- `AddFrameSettings(frame, settingsTable)` – adds setting rows. See widget pages for schemas.
- `AddFrameSettingsButton(frame, data)` – adds a custom button under the settings list. `data` needs `text` and `click` handler.
- `internal:RefreshSettings()` – re-evaluates `isEnabled`/`disabled` predicates on visible rows.
- `internal:RefreshSettingValues()` – re-runs `Setup` on visible rows to pull updated values after you mutate backing data in a `set(...)` handler.
- Settings rows support `tooltip = "..."` to show a GameTooltip on hover.

## Callbacks
- `RegisterCallback(event, callback)` – `event` is `"enter"`, `"exit"`, `"layout"`, `"layoutadded"`, `"layoutdeleted"`, `"layoutrenamed"`, `"layoutduplicate"`, or `"spec"`.
  - `layout` callback receives `(layoutName, layoutIndex)`.
  - `layoutadded` receives `(addedLayoutIndex, activateNewLayout, isLayoutImported, layoutType)`; `activateNewLayout=true` means Blizzard activated the new layout immediately; `isLayoutImported=true` distinguishes imports from copy/new; `layoutType` is from `Enum.EditModeLayoutType`.
  - `layoutdeleted` receives `(deletedLayoutIndex)`.
  - `layoutrenamed` receives `(oldName, newName, layoutIndex)`.
  - `layoutduplicate` receives `(addedLayoutIndex, duplicateIndices, isLayoutImported, layoutType)` when the added layout matches existing ones (uses `C_EditMode.ConvertLayoutInfoToString`; indices are UI indices, i.e. offset by +2 relative to `GetLayouts().layouts`).
  - `spec` receives `(currentSpecID)` (or nil if unavailable).
- `GetActiveLayoutName()` – returns the active Edit Mode layout.
- `GetActiveLayoutIndex()` – returns the active layout index.
- `IsInEditMode()` – returns `true` when Edit Mode is open.

- Reset behavior: the Reset button sets each setting to its `default` (and `colorDefault` for color-enabled rows) if provided; settings without a `default` are skipped.

## SettingType values
Available via `EditMode.SettingType`:
- `Checkbox`
- `Dropdown`
- `MultiDropdown`
- `Slider`
- `Color`
- `CheckboxColor`
- `DropdownColor`
- `Divider`
- `Collapsible`
