# Color

Color picker row.

Required fields:
- `name`
- `kind = EditMode.SettingType.Color`
- `default` (table or numbers `{ r, g, b, a? }`)
- `get(layoutName)` → color
- `set(layoutName, color)`

Options:
- `hasOpacity = true` to enable alpha channel
- `isEnabled(layoutName)` or `disabled(layoutName)`
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- `tooltip = "..."` to show a GameTooltip on hover


Example:
```lua
{
    name = "Bar color",
    kind = EditMode.SettingType.Color,
    default = { 0.2, 0.6, 1, 1 },
    hasOpacity = true,
    get = function(layout) return MyDB[layout].barColor end,
    set = function(layout, color) MyDB[layout].barColor = color end,
}
```

Example GIF:

