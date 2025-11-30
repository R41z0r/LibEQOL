# Checkbox + Color

Boolean toggle paired with a color picker.

Required fields:
- `name`
- `kind = EditMode.SettingType.CheckboxColor`
- `default` (boolean)
- `get(layoutName)` and `set(layoutName, value)` for the check state
- Color accessors (table `{ r, g, b, a? }`):
  - `colorGet(layoutName)` – return the current color table
  - `colorSet(layoutName, color)` or `setColor(layoutName, color)` – callback you implement to apply/save the provided color table
  - `colorDefault` – default color (same format)

Options:
- `hasOpacity = true` to allow alpha
- `isEnabled(layoutName)` or `disabled(layoutName)`
- `tooltip = "..."` to show a GameTooltip on hover
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- Note: the color swatch is only enabled when the checkbox is checked. If you need a different enable rule (e.g., “use class color” vs “custom color”), adjust your wording or use a separate color control (DropdownColor/Color) for the alternate case.


Example:
```lua
{
    name = "Glow",
    kind = EditMode.SettingType.CheckboxColor,
    default = true,
    colorDefault = { 1, 0.8, 0, 1 },
    get = function(layout) return MyDB[layout].glowEnabled end,
    set = function(layout, value) MyDB[layout].glowEnabled = value end,
    colorGet = function(layout) return MyDB[layout].glowColor end,
    colorSet = function(layout, color) MyDB[layout].glowColor = color end,
    hasOpacity = true,
}
```

Example GIF:

