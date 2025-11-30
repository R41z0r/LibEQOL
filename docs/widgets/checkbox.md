# Checkbox

Boolean toggle row.

Required fields:
- `name`
- `kind = EditMode.SettingType.Checkbox`
- `default` (boolean)
- `get(layoutName)` → boolean
- `set(layoutName, value)`

Optional:
- `isEnabled(layoutName)` or `disabled(layoutName)` to control availability.
- `isShown(layoutName)` or `hidden(layoutName)` to completely hide the row (layout resizes).
- `tooltip = "..."` to show a GameTooltip on hover.


Example:
```lua
{
    name = "Show title",
    kind = EditMode.SettingType.Checkbox,
    default = true,
    get = function(layout) return MyDB[layout].showTitle end,
    set = function(layout, value) MyDB[layout].showTitle = value end,
}
```
