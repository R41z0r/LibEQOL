# Changelog

## [5] - 2025-12-06

Bugfix:

- Duplicate load of XML templates shared across multiple addons fixed; template names are auto-suffixed via `@project-abbreviated-hash@` in the BigWigs packager to avoid “Deferred XML Node … already exists” when multiple embeds are present
