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
External resources must integrate through the TD-Housing public API instead of reading or writing the Housing database
directly.

## Architecture

The migrated TrueDane 3.0 path follows these boundaries:

```text
External product
    -> TD-Housing public export
    -> service
    -> repository
    -> Housing database
    -> in-memory property state / client synchronization
```

Framework and provider access is moving behind `td_bridge`. New TrueDane code must use the stable `TD` API.
Legacy `ps-housing:*` events remain internally while the original client/UI runtime is being migrated, but they are
not the integration contract for other TrueDane resources.

## Dependencies

Required runtime resources:

- `td_bridge`;
- `ox_lib`;
- `oxmysql`;
- `fivem-freecam`;
- a supported doorlock/provider setup selected by the Housing compatibility layer.

Provider-specific framework, inventory, target, wardrobe and garage resources must start before TD-Housing when selected.

## Public server API

The TrueDane integration contract currently exposes:

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

TD-Housing owns the `properties` table. Other TrueDane resources must not join against or mutate that table directly;
use the public API instead.

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

ensure td_bridge

# Selected doorlock / garage / wardrobe providers
ensure ox_doorlock

ensure fivem-freecam
ensure td_housing

# Products using Housing start afterwards
ensure td-business
ensure nrp_tablet
ensure td_realtor
```

Adjust provider names to the server configuration.

## Development status

The TrueDane 3.0 server boundary is active for ownership, access, property capabilities and Realtor property mutations.

The remaining migration debt is primarily inside the inherited Housing runtime:

- legacy `ps-housing:*` client event namespace;
- legacy Housing NUI source;
- remaining direct framework/provider calls in inherited runtime files;
- final provider-neutral migration of spawn, weather, garage and character-creation compatibility.

These internal compatibility surfaces must not be copied into new TrueDane code.

## CI

The repository CI currently verifies:

- StyLua formatting for migrated TrueDane Lua;
- Lua 5.4 syntax for migrated files;
- property capability tests;
- property mutation service tests;
- legacy NUI dependency installation;
- reporting of the remaining legacy NUI typecheck/build debt.

A green CI does not replace an in-game smoke test.

## Dev-server smoke test

At minimum test:

1. clean server/resource startup;
2. existing properties load after restart;
3. shell property entry/exit;
4. MLO door access;
5. owner access;
6. `resident` access;
7. guest access restrictions;
8. stash placement/opening;
9. wardrobe placement/use;
10. furniture modes `player`, `fixed` and `disabled`;
11. garage creation/use;
12. `RegisterProperty`;
13. `SetOwner`;
14. `UpdateShell`;
15. `UpdateGarage`;
16. `UpdateImages`;
17. access grant/revoke persistence;
18. restart persistence after mutations;
19. TD-Realtor sale ownership transfer;
20. TD-Realtor rental start/end flow.

Record Resmon idle and active figures before release.

## Development rules

Before a release:

- migrated Lua must pass StyLua and Lua 5.4 syntax checks;
- new framework/provider access must use `td_bridge`;
- protected mutations must be server-authoritative;
- database access for migrated domain logic belongs in repositories;
- domain rules belong in services;
- temporary debug/test commands must not ship;
- README, CHANGELOG and migrations must match the release;
- relevant in-game smoke tests and Resmon measurements must be recorded.
