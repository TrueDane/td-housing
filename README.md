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

The TrueDane 3.0 path follows these boundaries:

```text
External product
    -> TD-Housing public export
    -> service
    -> repository
    -> Housing database
    -> in-memory property state / client synchronization
```

Framework and provider access is isolated behind `td_bridge` or explicit integration adapters. New TrueDane code must use stable TrueDane boundaries instead of calling framework/provider resources directly.

The migrated runtime now routes player lifecycle, notifications, target/radial, inventory/stash state, MLO door lifecycle, garage integration, weather sync, spawn, wardrobe/appearance and first-character compatibility through `td_bridge`.

Legacy apartment persistence is isolated behind repository/service boundaries. Runtime property files do not access MySQL directly.

Legacy `ps-housing:*` events remain internally for compatibility with the inherited client runtime, but they are not the public integration contract for other TrueDane resources.

## Dependencies

Required runtime resources:

- `td_bridge` 0.7.0+;
- `ox_lib`;
- `oxmysql`;
- `fivem-freecam`;
- a doorlock provider selected in `td_bridge` (`ox_doorlock` or `qb_doorlock`).

Optional capabilities depend on configured bridge providers:

- garage: `qbx_garages` or `qb_garages`;
- weather sync: compatible QB/QBX weather provider;
- spawn: configured spawn provider;
- appearance/wardrobe: configured appearance provider;
- legacy apartment stash migration: supported inventory provider.

Provider-specific resources must start before TD-Housing when selected.

## Public server API

The TrueDane integration contract exposes:

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

Supported public access roles are:

- `owner` — derived from property ownership;
- `resident` — intended for tenants and other trusted residents;
- `guest` — door access without resident feature-management permissions;
- `visitor` — derived for players without access.

TD-Realtor rentals use `resident` access without transferring ownership.

### Property settings

`ApplyPropertySettings` supports the generic capability configuration used by Realtor and future products:

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

All protected state changes are validated server-side. Client state must not be treated as authoritative.

## Provider boundaries

TD-Housing does not call configured framework/provider resources directly from the migrated runtime.

Examples:

```lua
TD.Garage.RegisterHouse(source, garageId, garageData)
TD.Weather.SetSync(source, enabled)
TD.Spawn.Open(characterData)
TD.Appearance.OpenWardrobe()
TD.Appearance.CreateFirstCharacter(source)
TD.Inventory.ImportLegacyStash(...)
```

The `qbx_properties` compatibility hook is isolated in a named client integration instead of the Housing core.

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

TD-Housing owns the `properties` table. Other TrueDane resources must not join against or mutate that table directly; use the public API instead.

Database access in the migrated server runtime is centralized in repositories. Legacy-compatible mutation flows are routed through services instead of issuing SQL directly from `server.lua` or `sv_property.lua`.

Existing property data must be preserved during migration.

## Suggested start order

A typical development order is:

```cfg
ensure oxmysql
ensure ox_lib

# Framework/providers selected by td_bridge
ensure qbx_core
# ensure ox_inventory
# ensure ox_target

# Optional providers used by Housing
ensure ox_doorlock
ensure qbx_garages

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

- StyLua formatting for migrated Lua;
- Lua 5.4 syntax;
- provider-boundary rules for the migrated runtime;
- server-side garage ownership validation;
- repository/service persistence boundaries;
- property capability tests;
- property capability service tests, including stable stash IDs and safe removal;
- property mutation service tests;
- NUI dependency installation;
- NUI typecheck;
- NUI production build.

A green CI does not replace an in-game smoke test.

## Dev-server smoke test

Before release, test at minimum:

1. clean server/resource startup;
2. existing properties load after restart;
3. shell property entry/exit;
4. MLO door access;
5. owner access;
6. `resident` access;
7. guest access restrictions;
8. stash placement/opening;
9. verify a non-empty stash cannot be removed;
10. verify stash contents remain attached to the same furniture after restart/reordering;
11. wardrobe placement/use;
12. furniture modes `player`, `fixed` and `disabled`;
13. owner garage registration/use with the selected garage provider;
14. verify a non-owner cannot register another property's garage;
15. weather sync across shell entry/exit;
16. spawn flow;
17. first-character/appearance flow;
18. `RegisterProperty`;
19. `SetOwner`;
20. `UpdateShell`;
21. `UpdateGarage`;
22. `UpdateImages`;
23. access grant/revoke persistence;
24. restart persistence after mutations;
25. TD-Realtor sale ownership transfer;
26. TD-Realtor rental start/end flow.

Record Resmon idle and active figures before release.

## Development rules

Before a release:

- migrated Lua must pass StyLua and Lua 5.4 syntax checks;
- NUI must pass typecheck and production build;
- new framework/provider access must use `td_bridge` or an approved isolated integration;
- protected mutations must be server-authoritative;
- database access for migrated domain logic belongs in repositories;
- domain rules belong in services;
- temporary debug/test commands and release-preparation workflows must not ship;
- README, CHANGELOG and migrations must match the release;
- relevant in-game smoke tests and Resmon measurements must be recorded.
