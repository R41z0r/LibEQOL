# LibEQOL

Quality-of-life toolkit for WoW addons. It ships the Edit Mode helper sublib `LibEQOLEditMode-1.0` (Blizzard Edit Mode integration), the optional native helper sublib `LibEQOLNativeEditMode-1.0` (own manager/selection/snap/grid flow), and the Settings helper sublib `LibEQOLSettingsMode-1.0` (helpers for Blizzard Settings UI). `LibEQOL-1.0` remains a backward-compatible alias to `LibEQOLEditMode-1.0`.

Full docs live at: https://github.com/R41z0r/LibEQOL/wiki

## Requirements

- Retail WoW 10.0+ (uses Edit Mode APIs)
- LibStub (bundled by most addon frameworks)

## Install / embed

- **Standalone:** Drop `LibEQOL` into `Interface/AddOns` and enable it; it loads automatically.
- **Embedded:** Place the folder in `libs/` and include `LibEQOL.xml` in your TOC:
  ```
  <Include file="libs/LibEQOL/LibEQOL.xml" />
  ```
- **Optional native edit mode:** Keep the default include above unchanged and add this only if you want the native mode:
  ```
  <Include file="libs/LibEQOL/LibEQOLNativeEditMode.xml" />
  ```
- **Packaging (BigWigs packager):** Do **not** list LibEQOL as an External; it can bleed into other addons and create XML/template conflicts. Vendor it explicitly (e.g. with the GitHub Action below) into your `libs/` directory instead.

## GitHub Action helper

Use the published action in this repo to pull the latest LibEQOL release ZIP during CI and unpack it into your addon. Set `destination` to the folder that should contain `LibEQOL/` (for example `EnhanceQoL/libs`); the action creates that path, extracts the ZIP, and stages `destination/LibEQOL` in your repo.

```
- name: Install LibEQOL
  uses: R41z0r/LibEQOL@v1.0.0
  with:
    destination: EnhanceQoL/libs   # results in EnhanceQoL/libs/LibEQOL
```

Optional inputs: `repo` (defaults to this repo) and `github-token` (defaults to `github.token`). Outputs: `tag` and `asset_url` from the resolved release.

## Architecture

- Single-file design with explicit layers: state tracker, pool manager, widget builders, dialog controller, and selection handling.
- Modules under `LibEQOL`: **LibEQOLEditMode** (shipping), **LibEQOLNativeEditMode** (optional), and **LibEQOLSettingsMode** (shipping) share core helpers while exposing separate APIs.
- Umbrella entry (`LibEQOL.lua`) surfaces sublibs on `_G.LibEQOL` (`EditMode` and `SettingsMode` load with `LibEQOL.xml`; `NativeEditMode` resolves when `LibEQOLNativeEditMode.xml` is additionally loaded).
- All widgets are built on-demand from our factories; no embedded Blizzard UI copies or borrowed layout code.
- Public API for Edit Mode (`AddFrame`, `AddFrameSettings`, `AddFrameSettingsButton`, callbacks, `SettingType`, etc.) stays stable for drop-in compatibility.

## Getting started (TL;DR)

```lua
local EditMode = LibStub("LibEQOLEditMode-1.0")

-- 1) Make your frame moveable via Edit Mode
EditMode:AddFrame(MyFrame, function(frame, layoutName, point, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end, { point = "CENTER", x = 0, y = 0 })

-- 2) Optional: add settings rows under the Edit Mode dialog
EditMode:AddFrameSettings(MyFrame, {
    {
        name = "Show title",
        kind = EditMode.SettingType.Checkbox,
        default = true,
        get = function(layout) return MyDB[layout].showTitle end,
        set = function(layout, value) MyDB[layout].showTitle = value end,
    },
    {
        name = "Size",
        kind = EditMode.SettingType.Slider,
        minValue = 0.5,
        maxValue = 2,
        valueStep = 0.05,
        default = 1,
        get = function(layout) return MyDB[layout].scale end,
        set = function(layout, value) MyDB[layout].scale = value end,
        formatter = function(value) return string.format("%.2fx", value) end,
    },
})

-- 3) Optional: custom button under the settings list
EditMode:AddFrameSettingsButton(MyFrame, {
    text = "Open full config",
    click = function() OpenOptionsFrameToCategory("MyAddon") end,
})

-- 4) Optional: react to Edit Mode events
EditMode:RegisterCallback("layout", function(layoutName)
    print("Now editing layout:", layoutName)
end)
```

## Feature highlights

- Selection overlay and move handles that integrate with Blizzard Edit Mode selection/highlight.
- Keyboard nudging (arrow keys, Shift for larger steps) and reset-to-default positioning.
- Auto-built settings dialog with pooled widgets (checkbox, dropdown, multi dropdown, slider, color picker, checkbox+color, dropdown+color) and a built-in reset action.
- Optional max height for per-frame settings lists with automatic scrolling.
- Per-frame action buttons plus automatic "Reset Position" button (can be hidden).
- Optional checkbox panel under the Edit Mode manager for toggling your addon frames on/off.
- Callbacks for entering/exiting Edit Mode and when the active layout changes.
- Helpers to refresh setting enable states when your backing data changes.

## API quick reference

- `AddFrame(frame, callback, defaultPosition)` – register a frame for Edit Mode. `callback(frame, layoutName, point, x, y)` fires on move/reset; anchors stay relative to the frame’s current parent (or existing relative frame when nudging) and `defaultPosition` defaults to `{ point = "CENTER", x = 0, y = 0 }` relative to the parent. Opt-in overlay/label toggle via `defaultPosition.enableOverlayToggle = true` (or `overlayToggleEnabled = true`).
- Native-only control API (`LibEQOLNativeEditMode-1.0`): `EnterEditMode()`, `ExitEditMode()`, `ToggleEditMode()`, `SetSnapEnabled(enabled)`, `GetSnapEnabled()`, `SetGridEnabled(enabled)`, `GetGridEnabled()`, `SetGridSize(size)`, `GetGridSize()`.
- Reset button: sets settings back to their `default` (and `colorDefault` where applicable); settings without defaults are skipped.
- `AddFrameSettings(frame, settingsTable)` – supply rows for the settings dialog. See **Setting rows**.
- `AddFrameSettingsButton(frame, data)` – add a custom button (`text`, `click` handler) using the built-in Edit Mode extra button style.
- `SetFrameResetVisible(frame, showReset)` – hide or re-show the built-in "Reset Position" button.
- `SetFrameSettingsResetVisible(frame, showReset)` – hide or re-show the settings "Reset to Default" button for that frame.
- `SetFrameSettingsMaxHeight(frame, height)` – set a max height (in pixels) for the settings list only (button bar excluded); pass `nil` to clear the override.
- `SetFrameDragEnabled(frame, enabledOrPredicate)` – allow/deny drag + keyboard nudging for a frame; pass a boolean or function `(layoutName, layoutIndex)`; `nil` removes the override. You can also set `defaultPosition.allowDrag`/`dragEnabled` on `AddFrame`.
- `SetFrameOverlayToggleEnabled(frame, enabled)` – show/hide the eye-button for that frame; default is disabled until you opt-in.
- `SetFrameCollapseExclusive(frame, enabled)` – make collapsible headers on this frame exclusive (expanding one collapses the others). You can also set `defaultPosition.collapseExclusive` (alias `exclusiveCollapse`) on `AddFrame`.
- `AddManagerToggle(data)` / `AddManagerCheckbox(data)` – add a checkbox row under `EditModeManagerFrame` to show/hide frames. Provide `label`, `frames`, and optional `id`/`category` (if `id` is omitted, `label` is used as the id).
- `AddManagerCategory(data)` – register a category header (with optional sort) for manager toggles.
- `RemoveManagerToggle(id)` / `RefreshManagerToggles()` / `SetManagerTogglePanelMaxHeight(height)` – manage or resize the manager toggle panel.
- Default visibility flags on `AddFrame`: `default.showReset = false` hides the Reset Position button; `default.showSettingsReset = false` hides the Settings Reset button for that frame.
- Settings layout overrides on `AddFrame`: `default.settingsSpacing`, `default.settingsMaxHeight` (or `default.maxSettingsHeight`), `default.sliderHeight`, `default.dropdownHeight`, `default.multiDropdownHeight`, `default.multiDropdownSummaryHeight`, `default.checkboxHeight`, `default.colorHeight`, `default.checkboxColorHeight`, `default.dropdownColorHeight`, `default.inputHeight`, `default.dividerHeight`, `default.collapsibleHeight`.
- `RegisterCallback(event, callback)` – `event` is `"enter"`, `"exit"`, `"layout"`, `"layoutadded"`, `"layoutdeleted"`, `"layoutrenamed"`, `"layoutduplicate"`, or `"spec"`; `layout` callbacks receive `(layoutName, layoutIndex)`; `layoutadded` receives `(addedLayoutIndex, activateNewLayout, isLayoutImported, layoutType, layoutName)`; `layoutdeleted` receives `(deletedLayoutIndex, deletedLayoutName)` using the cached name from before the refresh; `layoutrenamed` receives `(oldName, newName, layoutIndex)` where `layoutIndex` is the UI index (custom layouts are offset by +2), and only fires for real rename operations (not index shifts caused by delete); `layoutduplicate` receives `(addedLayoutIndex, duplicateIndices, isLayoutImported, layoutType, layoutName)` (name is the new layout once, not per duplicate); `spec` receives the current spec index (from `GetSpecialization()`).
- `GetActiveLayoutName()` / `GetActiveLayoutIndex()` / `IsInEditMode()` – query current state.
- `GetLayouts()` – returns an array of `{ index, name, layoutType, isActive }` for UI indices (1/2 use `LAYOUT_STYLE_MODERN` / `LAYOUT_STYLE_CLASSIC` and `Enum.EditModeLayoutType.Modern` / `Enum.EditModeLayoutType.Classic` when available); `isActive` is `1` for the active layout, else `0`.
- `GetFrameDefaultPosition(frame)` – retrieve the default position for a registered frame.
- `lib.internal:RefreshSettings()` – re-evaluate `isEnabled`/`disabled` predicates on visible rows.

Example: `examples/EditModeExamples.lua` (https://raw.githubusercontent.com/R41z0r/LibEQOL/main/examples/EditModeExamples.lua) includes an "Overlay Toggle" frame showing how to opt into the eye-button via `enableOverlayToggle = true`. Native example: `examples/NativeEditModeExamples.lua` (`/eqolnative` to toggle). Also see `docs/overlay-toggle-example.lua`. GIF: https://raw.githubusercontent.com/wiki/R41z0r/LibEQOL/assets/widgets/frames/example-hideoverlay.gif

## Setting rows (schema + examples)

Each row needs `name`, `kind`, `get(layoutName)`, `set(layoutName, value)`, and `default`. Optional `isEnabled(layoutName)` or `disabled(layoutName)` toggle availability.

Kinds (from `EditMode.SettingType`):

- `Checkbox` – boolean toggle.
- `Dropdown` – either `values = { { text = "Option" }, ... }` or a `generator(owner, rootDescription, data)` for dynamic menus. Single-select; use `MultiDropdown` for checkbox menus. Optional `height` to force scrolling.
- `MultiDropdown` – checkbox menu that returns a map of selected values; supports `values`/`options`, optional `optionfunc(layout)`, `isSelected`, and `setSelected`. Optional `height` to force scrolling.
- `Slider` – `minValue`, `maxValue`, optional `valueStep`, `formatter`, `allowInput` (show text box).
- `Input` – plain text/number input with optional `numeric`, `maxChars`, `inputWidth`, `readOnly`.
- `Color` – values resolve to `{ r, g, b, a? }`; set `hasOpacity` to allow alpha.
- `CheckboxColor` – boolean + color. Use `colorGet(layout)` and `colorSet(layout, color)` (or `setColor`) plus `colorDefault`.
- `DropdownColor` – dropdown behavior plus a color swatch via `colorGet`/`colorSet`.
- `tooltip = "..."` can be added to any row to show a GameTooltip on hover.

## Distribution tips

- Keep `LibStub` loading before `LibEQOL.lua` when embedding.
- If you rely on load-on-demand, list `LibEQOL` in `OptionalDeps` so the library is ready before your code runs.

## Troubleshooting

- If a frame does not move, ensure it is parented and not forbidden during combat; Edit Mode is blocked in combat.
- Call `lib.internal:RefreshSettings()` after you mutate data that controls `isEnabled`/`disabled` logic for visible rows.
