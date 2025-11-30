# Divider

Horizontal divider row.

Required fields:
- `name` (ignored)
- `kind = EditMode.SettingType.Divider`

Options:
- `isShown(layoutName)` or `hidden(layoutName)` to hide the row entirely (layout resizes)

Notes:
- No `get`/`set` required; this is purely visual.
- Divider texture matches Blizzard’s `UI-FriendsFrame-OnlineDivider` (330x16).

Example:
