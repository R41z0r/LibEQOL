# Changelog

## [6] - 2025-12-07

Added:
- EditMode: Snap-to-grid/magnetism support with preview; frames expose Blizzard’s magnetism API and snap on drag finish when snapping is enabled.
- Settings: Top-level `order = { ... }` for map-based dropdowns (single, multi, sound) to control option ordering.
- Settings: `defaultSelection` for multi dropdowns so “Reset to default” restores a defined selection (defaults to empty).
- Settings: Color overrides can tint labels via `colorizeLabel`/`colorizeText` (doc’d).
- Settings: Sound dropdown honors disabled state on init and greys out its label when parent checks disable it.

Fixed:
- Multi dropdown `hideSummary` now respected again.
- Rounded position offsets when firing EditMode callbacks to avoid tiny float drift.

## [5] - 2025-12-06

Bugfix:

- Duplicate load of XML templates shared across multiple addons fixed; template names are auto-suffixed via `@project-abbreviated-hash@` in the BigWigs packager to avoid “Deferred XML Node … already exists” when multiple embeds are present
