# Changelog

All notable TD-Housing TrueDane 3.0 migration changes are documented here.

## [Unreleased]

### Runtime migration

- Consolidated the Housing runtime on `td_bridge` 0.7.0+ for doorlock, garage, weather, spawn and appearance capabilities.
- Routed property weather sync enable/disable through `TD.Weather.SetSync` and removed direct `qb-weathersync` calls from the migrated lifecycle.
- Routed property garage registration and QB house-garage client lifecycle through `TD.Garage` and removed direct `qbx_garages` / `qb-garages` calls.
- Added server-side ownership validation before a client-triggered property garage can be registered.
- Routed spawn UI through `TD.Spawn`, capability-gating provider-specific starting-apartment selection instead of assuming QB Spawn behavior.
- Routed wardrobe and first-character creation through `TD.Appearance`, removing direct clothing/appearance provider events from Housing core.
- Isolated legacy appearance persistence in a repository and first-character orchestration in a service.
- Isolated legacy apartment stash lookup/deletion in a repository and migration service.
- Legacy stash imports now use `TD.Inventory.ImportLegacyStash`; source data is deleted only after a successful import.
- Kept the legacy `qb-apartments:returnBucket` event only in the explicit compatibility module.
- Expanded provider-boundary CI so direct garage, weather, spawn, clothing and inventory provider calls cannot return to migrated Housing core.

### NUI

- Repaired invalid Threlte modeler transform markup that prevented Svelte/TypeScript validation.
- NUI typecheck and production build now complete successfully on the release-ready branch.
- Generated `html` assets are rebuilt from the validated UI source.

### Security

- Client garage registration sends only the property ID; server-owned property state determines coordinates, owner access and provider payloads.
- Legacy apartment migration no longer deletes source stash data before the destination import succeeds.
- Existing server-authoritative storage removal and non-empty stash protection remain enforced.

## 0.1.0-dev - 2026-09-28

### Runtime migration

- Routed the Housing compatibility wrapper for notifications, target, radial and stash registration through `td_bridge`.
- Corrected TD-Target option names to the normalized `on_select` / `can_interact` contract.
- Property raid authorization now reads normalized job/duty/grade state through `TD.Player` and stormram state through `TD.Inventory`.
- Player identifier and character-name lookup now use the normalized bridge contract where migrated.
- Storage furniture now persists a stable `stash_id` so stash contents do not move when furniture ordering changes.
- Storage removal is server-authoritative and refuses non-empty or unverifiable stashes.
- TD-Housing runtime storage removal requires `td_bridge` 0.6.2+ with `TD.Inventory.IsEmpty`.
- MLO door creation, lookup, character access, raid unlock and supported deletion now use the `TD.Door` boundary from `td_bridge` 0.6.3+.
- Added regression coverage for stable stash migration, non-empty stash protection and normalized Realtor duty handling.

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

The inherited `ps-housing:*` runtime remains internally for legacy client compatibility while the remaining client/runtime migration is completed. New TrueDane integrations must not depend on that namespace.
