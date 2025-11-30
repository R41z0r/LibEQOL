# Slider

Numeric slider row with optional text input.

Required fields:
- `name`
- `kind = EditMode.SettingType.Slider`
- `default`
- `minValue`, `maxValue`
- `get(layoutName)` → number
- `set(layoutName, value)`

Options:
- `valueStep` (default: 1)
- `formatter(value)` to format right-hand text
- `allowInput = true` to show a text box
- `isEnabled(layoutName)` or `disabled(layoutName)`
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- `tooltip = "..."` to show a GameTooltip on hover


Example:
```lua
{
    name = "Scale",
    kind = EditMode.SettingType.Slider,
    minValue = 0.5,
    maxValue = 2,
    valueStep = 0.05,
    default = 1,
    get = function(layout) return MyDB[layout].scale end,
    set = function(layout, value) MyDB[layout].scale = value end,
    formatter = function(value) return string.format("%.2fx", value) end,
    allowInput = true,
}
```

Example GIFs:


