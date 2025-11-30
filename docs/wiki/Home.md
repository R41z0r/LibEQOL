# LibEQOL Wiki

Quality-of-life library for WoW. Current module: `LibEQOLEditMode` helper (selection overlays, dialogs, widgets). Planned: `LibEQOLSettingsMode` using the same core stack. The umbrella loader (`LibEQOL.lua`) surfaces sublibs on `_G.LibEQOL`.

- [[getting-started]]
- [[api]]
- Widgets
  - [[Checkbox|checkbox]]
  - [[Dropdown|dropdown]]
  - [[Multi Dropdown|multi-dropdown]]
  - [[Slider|slider]]
  - [[Color|color]]
  - [[Checkbox + Color|checkbox-color]]
  - [[Dropdown + Color|dropdown-color]]
  - [[Divider|divider]]
  - [[Collapsible|collapsible]]

Tips: load `LibStub` before the library when embedding; Edit Mode is blocked in combat.
