# LibEQOL Docs

Landing page for the library. For the quick overview, see the README; for deeper usage per widget/API, follow the links below.

Modules:
- LibEQOLEditMode (current) – selection overlays, dialogs, widgets (see links below).
- LibEQOLSettingsMode (planned) – will reuse the core helper stack once shipped.

The umbrella loader (`LibEQOL.lua`) exposes sublibs on `_G.LibEQOL`; EditMode is included by default.

- [Getting started](getting-started.md)
- [API reference](api.md)
- Widgets
  - [Checkbox](widgets/checkbox.md)
  - [Dropdown](widgets/dropdown.md)
  - [Multi Dropdown](widgets/multi-dropdown.md)
  - [Slider](widgets/slider.md)
  - [Color](widgets/color.md)
  - [Checkbox + Color](widgets/checkbox-color.md)
  - [Dropdown + Color](widgets/dropdown-color.md)
  - [Divider](widgets/divider.md)
  - [Collapsible](widgets/collapsible.md)

If you maintain your docs on GitHub, you can point Pages to `/docs` or link these files directly from the README.
