# Dropdown + Color

Dropdown row with a color swatch.

Required fields:
- `name`
- `kind = EditMode.SettingType.DropdownColor`
- `default` (dropdown value)
- `get(layoutName)` / `set(layoutName, value)` for the dropdown selection
- Color accessors (table `{ r, g, b, a? }`):
  - `colorGet(layoutName)` – return the current color table
  - `colorSet(layoutName, color)` or `setColor(layoutName, color)` – callback to apply/save the provided color table
  - `colorDefault` – default color (same format)

Options:
- `values` or `generator` (same as plain dropdown)
- `height` for scrollable menus
- `hasOpacity = true` to allow alpha
- `isEnabled(layoutName)` or `disabled(layoutName)`
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- `tooltip = "..."` to show a GameTooltip on hover


Example:
```lua
{
    name = "Bar texture",
    kind = EditMode.SettingType.DropdownColor,
    default = "DEFAULT",
    values = {
        { text = "Default", isRadio = true },
        { text = "Smooth",  isRadio = true },
        { text = "Flat",    isRadio = true },
    },
    get = function(layout) return MyDB[layout].texture end,
    set = function(layout, value) MyDB[layout].texture = value end,
    colorDefault = { 0.2, 0.8, 0.2, 1 },
    colorGet = function(layout) return MyDB[layout].textureColor end,
    colorSet = function(layout, color) MyDB[layout].textureColor = color end,
    hasOpacity = true,
}
```
