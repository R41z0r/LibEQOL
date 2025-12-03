# LibEQOL

Quality-of-life toolkit for WoW addons. Ships the Edit Mode helper sublib `LibEQOLEditMode-1.0` (selection overlays, dialogs, widgets) and the Settings helper sublib `LibEQOLSettingsMode-1.0` (helpers for the Blizzard Settings UI).

## What you get

- Edit Mode: selection overlay that plugs into Blizzard highlight, move handles, keyboard nudging (Shift for larger steps), per-frame reset and optional overlay toggle eye-button, overlap chooser when frames stack, callbacks for enter/exit/layout/spec, and an auto-built settings panel (checkbox, dropdown, multi dropdown, slider, color, checkbox+color, dropdown+color) with pooled widgets.
- Settings Mode: helper layer for Blizzard Settings, powered by the same widget factory (checkbox/dropdown/multi dropdown/slider/color/sound); requires a unique `SetVariablePrefix` per addon to avoid collisions; supports per-control prefixes/variables, notify hooks, and "New" badges with auto-prefixed IDs.

## Requirements

- Retail WoW 10.0+ (uses Edit Mode APIs)
- LibStub (bundled by most addon frameworks)

## Install / embed

- Standalone: drop `LibEQOL` into `Interface/AddOns` and enable it (loads automatically).
- Embedded: place it under `libs/` and include `LibEQOL.xml`:
  ```
  <Include file="libs/LibEQOL/LibEQOL.xml" />
  ```

## Quick start (Edit Mode)

```lua
local EditMode = LibStub("LibEQOLEditMode-1.0")

EditMode:AddFrame(MyFrame, function(frame, layoutName, point, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end, { point = "CENTER", x = 0, y = 0 })

EditMode:AddFrameSettings(MyFrame, {
    {
        name = "Show title",
        kind = EditMode.SettingType.Checkbox,
        default = true,
        get = function(layout) return MyDB[layout].showTitle end,
        set = function(layout, value) MyDB[layout].showTitle = value end,
    },
})
```

## Quick start (Settings Mode)

```lua
local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
SettingsLib:SetVariablePrefix("MyAddon_") -- required, unique per addon

local root = SettingsLib:CreateRootCategory("My AddOn")
SettingsLib:CreateCheckbox(root, {
    key = "ShowTitle",
    name = "Show title",
    default = true,
    get = function() return MyDB.showTitle end,
    set = function(value) MyDB.showTitle = value end,
    desc = "Toggle the title text on your frame.",
})
SettingsLib:CreateSlider(root, {
    key = "Scale",
    name = "Scale",
    min = 0.5, max = 2, step = 0.05,
    default = 1,
    get = function() return MyDB.scale end,
    set = function(value) MyDB.scale = value end,
    formatter = function(value) return string.format("%.2fx", value) end,
})
```

## Tips

- `SetFrameDragEnabled`/`dragEnabled` let you allow/deny dragging; `enableOverlayToggle` opts into per-frame eye buttons; the overlap chooser appears when multiple registered frames sit under the cursor.
- Call `lib.internal:RefreshSettings()` after you change data that controls `isEnabled`/`disabled` logic on visible rows.
- Keep `LibStub` loading before `LibEQOL.lua`, and list `LibEQOL` in `OptionalDeps` if you load on demand.
