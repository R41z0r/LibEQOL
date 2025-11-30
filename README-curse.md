# LibEQOL

Lightweight Edit Mode helper sublib `LibEQOLEditMode-1.0` for Blizzard Edit Mode. Provides selection overlays, ready-made setting widgets (checkbox/dropdown/multi-dropdown/slider/color, incl. checkbox+color and dropdown+color), keyboard nudging, reset-to-default, and callbacks for enter/exit/layout. `LibEQOL-1.0` stays as an alias for existing users.

Docs: https://github.com/R41z0r/LibEQOLWiki/wiki

## Install / embed
- Standalone: drop `LibEQOL` into `Interface/AddOns` and enable it (loads automatically).
- Embedded: include `LibEQOL.xml` from your `libs/` folder:
  ```
  <Include file="libs/LibEQOL/LibEQOL.xml" />
  ```

## Quick start
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

## Notes
- `AddFrame` callback signature: `callback(frame, layoutName, point, x, y)`; positions are relative to `UIParent` and `relativePoint` equals `point`. `defaultPosition` can include `relativePoint` (handled the same as `point`).
- Reset button: sets settings back to their `default` (and `colorDefault` where applicable); settings without defaults are skipped.
- Any row can take `tooltip = "..."` to show a GameTooltip on hover.
- Umbrella entry (`LibEQOL.lua`) exposes sublibs on `_G.LibEQOL`; `EditMode` is present by default and future modules (e.g. settings) will sit alongside it.
