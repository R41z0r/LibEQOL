# Dropdown

Single-select dropdown (radio buttons or custom generator). For multi-select menus with a summary line, use [[Multi Dropdown|multi-dropdown]].

Required fields:
- `name`
- `kind = EditMode.SettingType.Dropdown`
- `default` (value)
- `get(layoutName)` → value
- `set(layoutName, value)`

Options:
- `values = { { text = "Option", value = "Key?", isRadio = true? }, ... }` (set `isRadio = true` for the normal radio style; if `value` is omitted, `text` is used as the value)
- `generator(owner, rootDescription, data)` for fully custom menus
- `height` to force a scrollable menu
- `isEnabled(layoutName)` or `disabled(layoutName)`
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- `tooltip = "..."` to show a GameTooltip on hover


Example (radio list):
```lua
{
    name = "Direction",
    kind = EditMode.SettingType.Dropdown,
    default = "UP",
    values = {
        { text = "Up", isRadio = true },
        { text = "Down", isRadio = true },
        { text = "Left", isRadio = true },
        { text = "Right", isRadio = true },
    },
    get = function(layout) return MyDB[layout].direction end,
    set = function(layout, value) MyDB[layout].direction = value end,
}
```

Example GIF:

