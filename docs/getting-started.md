# Getting started

A minimal path to embed and use the `LibEQOLEditMode` sublib from `LibEQOL`.

## Install / embed
- Standalone: drop `LibEQOL` into `Interface/AddOns` and enable it (loads automatically).
- Embedded: place it under `libs/` and include the XML before you call the API.
  ```
  <Include file="libs/LibEQOL/LibEQOL.xml" />
  ```

## First frame
```lua
local EditMode = LibStub("LibEQOLEditMode-1.0")

-- Make a frame movable via Edit Mode
EditMode:AddFrame(MyFrame, function(frame, layoutName, point, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end, { point = "CENTER", x = 0, y = 0 })
```

## Add settings rows
```lua
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
```

## Buttons and callbacks
```lua
EditMode:AddFrameSettingsButton(MyFrame, {
    text = "Open full config",
    click = function() OpenOptionsFrameToCategory("MyAddon") end,
})

EditMode:RegisterCallback("layout", function(layoutName)
    print("Now editing layout:", layoutName)
end)
```

## Tips
- Entry point: `LibStub("LibEQOLEditMode-1.0")`; `LibEQOL-1.0` stays as a compatibility alias.
- Load `LibStub` before the library when embedding.
- Edit Mode is blocked in combat; movement callbacks will not fire there.
- Call `EditMode.internal:RefreshSettings()` after changing data that drives `isEnabled`/`disabled` logic for visible rows.
- Call `EditMode.internal:RefreshSettingValues()` if you mutate other setting values inside a `set(...)` handler and want the visible rows to update immediately.
- Arrow keys nudge the selected frame (Shift for larger steps) while Edit Mode is active.
- `AddFrame` callback signature: `callback(frame, layoutName, point, x, y)`; positions are relative to `UIParent` and `relativePoint` equals `point`. `defaultPosition` supports `point`, optional `relativePoint`, `x`, and `y`.
