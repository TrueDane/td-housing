# TD-Housing

TD-Housing is the TrueDane 3.0 housing engine.

It owns the physical and persistent housing layer used by products such as `td_realtor`:

- property registration and lookup;
- shells, MLOs and entry state;
- ownership;
- resident and guest access;
- garages;
- furniture;
- stash and wardrobe capabilities;
- property-specific feature settings.

Business workflows such as valuation, auctions, sales, leases and Realtor-company ownership belong in `td_realtor`.
External resources must integrate through the TD-Housing public API instead of reading or writing the Housing database directly.

## Architecture

The TrueDane 3.0 integration path is:

```text
External product
    -> TD-Housing public export
    -> service
    -> repository
    -> Housing database
    -> in-memory property state / client synchronization
```

Provider access belongs behind `td_bridge`. The migrated runtime uses normalized bridge capabilities for player/framework state, callbacks, notifications, target/radial interactions, inventory/stashes, doorlocks, garages, weather sync, spawn and appearance/wardrobe functionality.

Legacy `ps-housing:*` events remain an internal compatibility surface while the inherited runtime is being retired. They are not a supported integration API for other TrueDane resources.

## Dependencies

Required runtime resources:

- `td_bridge` 0.7.0+;
- `ox_lib`;
- `oxmysql`;
- `fivem-freecam`;
- a doorlock provider selected in `td_bridge` (`ox_doorlock` or `qb_doorlock`).

Optional Housing features use explicitly selected `td_bridge` providers:

- garage: `qbx_garages` or `qb_garages`;
- weather: `qbx_weathersync` or `qb_weathersync`;
- spawn: `qbx_spawn` or `qb_spawn`;
- appearance: `illenium_appearance` or `qb_clothing`.

The selected provider resources must be available before their capabilities are used.

## Public server API

```lua
exports['td_housing']:RegisterProperty(propertyData, preventEnter, playerSource)
exports['td_housing']:GetProperty(propertyId)
exports['td_housing']:GetOwnedProperties(identifier)

exports['td_housing']:SetOwner(propertyId, identifier)
exports['td_housing']:UpdateShell(propertyId, shell)
exports['td_housing']:UpdateGarage(propertyId, garage)
exports['td_housing']:UpdateImages(propertyId, images)

exports['td_housing']:GetPropertyCapabilities(propertyId)
exports['td_housing']:ApplyPropertySettings(propertyId, settings)
exports['td_housing']:GrantAccess(propertyId, identifier, role)
exports['td_housing']:RevokeAccess(propertyId, identifier)
```

### Access roles

- `owner` — derived from property ownership;
- `resident` — tenant/trusted resident access;
- `guest` — door access without resident feature-management permissions;
- `visitor` — derived for players without access.

TD-Realtor rentals use `resident` access without transferring ownership.

### Property settings

```lua
{
    furnitureMode = 'player', -- player | fixed | disabled
    storage = {
        enabled = true,
        maxPlacements = 1,
    },
    wardrobe = {
        enabled = true,
        maxPlacements = 1,
    },
}
```

All protected state changes are validated server-side. Client state is never authoritative.

## Provider boundaries

### Garage

The client sends only the property ID. TD-Housing resolves authoritative garage data and ownership server-side before calling `TD.Garage.RegisterHouse`. Direct `qbx_garages` / `qb-garages` calls are rejected by CI on the migrated runtime path.

### Weather

Shell entry/exit uses `TD.Weather.SetSync`. Weather integration is capability-gated and remains optional.

### Spawn

Housing uses `TD.Spawn.Open`. Starting-apartment selection uses `TD.Spawn.OpenStartingApartments` only when the selected provider advertises that capability. Providers without that portable feature fall back to their generic spawn flow instead of receiving fabricated provider calls.

### Appearance and wardrobe

Wardrobes use `TD.Appearance.OpenWardrobe`; first-character creation uses `TD.Appearance.CreateFirstCharacter`. Housing no longer calls `qb-clothing`, `qb-clothes` or Illenium events directly on the migrated path.

### Legacy apartment stash migration

Legacy QB apartment stash lookup/deletion is isolated in a repository and migration service. Item import goes through `TD.Inventory.ImportLegacyStash` and the old stash is deleted only after a successful import, preventing the previous delete-before-save data-loss risk.

## Database

Base schema:

```text
sql/td_housing.sql
```

Apply migrations in order:

```text
migrations/001_property_capabilities.sql
migrations/002_remove_framework_owner_fk.sql
```

TD-Housing owns the `properties` table. Other TrueDane resources must use the public API rather than joining or mutating Housing tables directly.

Existing property data must be preserved during migration.

## Suggested start order

```cfg
ensure oxmysql
ensure ox_lib

# Framework and selected providers
ensure qbx_core
# ensure ox_inventory
# ensure ox_target
# ensure ox_doorlock
# ensure qbx_garages
# ensure qbx_spawn
# ensure illenium-appearance

ensure td_bridge
ensure fivem-freecam
ensure td_housing

# Products using Housing start afterwards
ensure td-business
ensure nrp_tablet
ensure td_realtor
```

Adjust provider names to the server configuration.

## CI

The repository CI verifies:

- StyLua formatting for migrated TrueDane Lua;
- Lua 5.4 syntax;
- runtime provider-boundary rules;
- server-side garage ownership validation;
- property capability and mutation tests;
- stable stash IDs and non-empty stash protection;
- NUI dependency installation;
- NUI Svelte/TypeScript checks;
- NUI production build.

A green CI does not replace an in-game smoke test.

## Remaining inherited migration debt

The provider migration is consolidated, but these inherited surfaces still require deliberate cleanup or final validation before a stable release:

- legacy internal `ps-housing:*` event namespace;
- remaining inherited direct property SQL in legacy lifecycle code must continue moving into repositories/services;
- `qbx_properties` compatibility detection remains an isolated product compatibility path;
- final TrueDane/Nexgen visual polish of the inherited furniture/modeler NUI;
- real FiveM smoke testing and Resmon measurements.

Do not copy these compatibility surfaces into new TrueDane code.

## Dev-server smoke test

At minimum test:

1. clean server/resource startup;
2. existing properties load after restart;
3. shell property entry/exit and weather restore;
4. MLO door access;
5. owner access;
6. `resident` access;
7. guest access restrictions;
8. stash placement/opening;
9. non-empty stash removal rejection;
10. stash contents remain attached after restart/reordering;
11. wardrobe placement/use;
12. furniture modes `player`, `fixed` and `disabled`;
13. garage registration/use;
14. non-owner garage registration rejection;
15. generic spawn flow;
16. starting-apartment spawn flow for providers that support it;
17. first-character appearance flow;
18. legacy apartment stash migration without data loss;
19. `RegisterProperty`;
20. `SetOwner`;
21. `UpdateShell`;
22. `UpdateGarage`;
23. `UpdateImages`;
24. access grant/revoke persistence;
25. restart persistence after mutations;
26. TD-Realtor sale ownership transfer;
27. TD-Realtor rental start/end flow.

Record real Resmon idle and active figures before release.

## Development rules

Before release:

- Lua must pass StyLua and Lua 5.4 syntax checks;
- NUI must format/lint/typecheck/build as configured by the project;
- new framework/provider access must use `td_bridge`;
- protected mutations must be server-authoritative;
- database access for migrated domain logic belongs in repositories;
- domain rules belong in services;
- temporary debug/test commands must not ship;
- README, CHANGELOG and migrations must match the release;
- relevant in-game smoke tests and Resmon measurements must be recorded.
