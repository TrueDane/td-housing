# Changelog

All notable TD-Housing TrueDane 3.0 migration changes are documented here.

## 0.1.0 - 2026-10-06

### Architecture

- Added the TrueDane 3.0 public Housing boundary for property registration, lookup, ownership, access and capabilities.
- Added `GetOwnedProperties`, `SetOwner`, `UpdateShell`, `UpdateGarage`, `UpdateImages`, capability reads and access mutation exports.
- Centralized Housing database access in repositories.
- Routed legacy-compatible property mutations through services instead of direct SQL in `server.lua` / `sv_property.lua`.
- Isolated the remaining `qbx_properties` compatibility hook in a named integration.

### Runtime migration

- Routed framework/player state, notifications, target, radial and inventory/stash access through `td_bridge`.
- Routed MLO door creation, lookup, access, raid unlock and supported deletion through `TD.Door`.
- Routed garage registration and QB house-garage lifecycle through `TD.Garage`.
- Routed shell weather sync through `TD.Weather`.
- Routed spawn flow through `TD.Spawn`.
- Routed wardrobe and first-character compatibility through `TD.Appearance`.
- Routed legacy apartment stash migration through `TD.Inventory`.
- Removed direct `qb-spawn`, `qb-clothing`, `qb-clothes`, `qb-inventory`, `qb-weathersync`, `qbx_garages` and `qb-garages` calls from the migrated Housing core.
- Added server-side ownership validation before property garage registration.
- Kept legacy `ps-housing:*` events internally for compatibility while making the public TrueDane API the supported integration boundary.

### Storage and access safety

- Added stable `stash_id` persistence so stash contents do not move when furniture ordering changes.
- Storage removal is server-authoritative and refuses non-empty or unverifiable stashes.
- Added `resident` and `guest` access roles with capability-aware stash, wardrobe and furniture behavior.
- Added server-side validation for protected property mutations.

### NUI

- Repaired the inherited Modeler markup so the NUI typechecks again.
- Restored a clean production build.
- Aligned the furniture/modeler UI styling with the TrueDane/Nexgen UI palette while preserving existing functionality.
- NUI typecheck and production build are now hard CI gates instead of warning-only checks.

### CI and quality

- Added StyLua and Lua 5.4 validation for the migrated runtime.
- Added provider-boundary regression checks.
- Added property capability, capability service and mutation service tests.
- Added regression coverage for stable stash IDs, non-empty stash protection and server-authoritative garage registration.
- Removed temporary release-preparation workflows from the release-ready branch.

### Compatibility

- TD-Housing requires `td_bridge` 0.7.0+ for the consolidated TrueDane 3.0 runtime boundary.
- Existing property data and legacy-compatible internal event flows are preserved during migration.
- New TrueDane integrations must use the public Housing API and must not depend on internal `ps-housing:*` events or the Housing database schema.
