# Multi Dropdown

Checkbox-style dropdown that allows multiple selections and shows a condensed summary underneath.


Required fields:
- `name`
- `kind = EditMode.SettingType.MultiDropdown`
- `default` (table – map of `value = true` or an array of selected values)
- `get(layoutName)` → selection table (map or array)
- `set(layoutName, selectionMap)` **or** `setSelected(layoutName, value, isSelected)`

Options:
- `values = { { text = "Option", value = "Key" }, ... }` (array or key/value table; plain strings/numbers are accepted)
- `options` (same shape as `values`) or `optionfunc(layoutName)` to supply a dynamic list
- `isSelected(layoutName, value)` to override the selection lookup
- `setSelected(layoutName, value, isSelected)` if you want to handle toggles individually instead of receiving a map
- `height` to force a scrollable menu
- `isEnabled(layoutName)` or `disabled(layoutName)` to toggle availability
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)
- `tooltip = "..."` to show a GameTooltip on hover
- `hideSummary = true` to remove the summary line under the dropdown (reduces height)

Example:
```lua
{
    name = "Show Roles",
    kind = EditMode.SettingType.MultiDropdown,
    field = "roles",
    default = { TANK = true, HEALER = true },
    values = {
        { text = "Tank", value = "TANK" },
        { text = "Healer", value = "HEALER" },
        { text = "DPS", value = "DPS" },
    },
}
```

