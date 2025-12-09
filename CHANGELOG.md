# Changelog

## [7] - 2025-12-09

Added:
- Settings: Color Overrides can opt into alpha via `hasOpacity = true`; supports ColorMixin callbacks (`getColorMixin`/`setColorMixin`/`getDefaultColorMixin`) alongside numeric RGB(A).
- Settings: Color Overrides now auto-size based on entry count (no more overlap) and respect `spacing`/`rowHeight`; hover highlight removed to match Blizzard.
- Docs: Settings pages aligned to real APIs (prefix/variable requirement, Color Overrides alpha/mixin example, option defaults).
- Settings: New checkbox+dropdown combined control using Blizzard’s template.
- Settings: New checkbox+slider combined control using Blizzard’s template.
- Settings: New checkbox+button combined control using Blizzard’s template.

Fixed:
- Settings: Color Overrides label color pooling no longer leaks between rows; defaults restored on reuse.
- Settings: Multi Dropdown forwards `customText`/`customDefaultText` and `callback` to the mixin again.
- Settings: Color Overrides padding default reduced to zero to avoid extra trailing space; extent respects explicit `basePadding`/`minHeight`/`height`.

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
