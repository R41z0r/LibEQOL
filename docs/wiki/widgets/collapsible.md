# Collapsible

Collapsible header row that can hide/show following settings sharing its `parentId`.

Required fields:
- `name` (header text)
- `kind = EditMode.SettingType.Collapsible`
- `id` (string; used to track collapse state and match children via `parentId`)

Optional:
- `defaultCollapsed` (boolean; `true` to start collapsed when no stored state exists)
- `getCollapsed(layoutName, layoutIndex)` / `setCollapsed(layoutName, collapsed, layoutIndex)` to manage state yourself; otherwise the library stores per-frame/per-layout state.
- `isShown(layoutName)` or `hidden(layoutName)` to hide the header entirely (children stay hidden when parent is hidden).
- Child settings should set `parentId = "yourId"`; they are auto-hidden when the header is collapsed.

Notes:
- No `get`/`set` for values; it only controls visibility of grouped children.
- Uses a stretch-style header with a plus/minus icon.

Example:
