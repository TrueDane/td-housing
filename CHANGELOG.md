# Changelog

All notable TD-Housing TrueDane 3.0 migration changes are documented here.

## [Unreleased]

## 0.1.0-dev - 2026-09-28

### Added

- Added the TrueDane 3.0 public Housing boundary for property registration, lookup, ownership and capabilities.
- Added `GetOwnedProperties` for provider-safe ownership reads without external database joins.
- Added dedicated `UpdateShell`, `UpdateGarage` and `UpdateImages` exports.
- Added server-side property mutation validation and persistence through the Housing repository.
- Added `resident` and `guest` access roles with capability-aware stash, wardrobe and furniture behavior.
- Added property capability and property mutation unit tests.

### Changed

- TD-Realtor can now perform Housing reads and mutations entirely through the public API.
- Housing database ownership is explicitly isolated inside TD-Housing.
- Migrated TrueDane files are covered by StyLua and Lua 5.4 CI checks.

### Compatibility

The inherited `ps-housing:*` runtime remains internally for legacy client compatibility while the remaining client/NUI
migration is completed. New TrueDane integrations must not depend on that namespace.
