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

Framework and provider access is moving behind `td_bridge`. New TrueDane code must use the stable `TD` API. The migrated compatibility layer now routes notifications, target zones/entities, radial items, stash registration, MLO door lifecycle and property garage integration through `td_bridge`.
Legacy `ps-housing:*` events remain internally while the original client/UI runtime is being migrated, but they are
not the integration contract for other TrueDane resources.

## Dependencies

Required runtime resources:

- `td_bridge` 0.6.4+;
- `ox_lib`;
- `oxmysql`;
- `fivem-freecam`;
- a doorlock provider selected in `td_bridge` (`ox_doorlock` or `qb_doorlock`).

Properties that use garages additionally require a garage provider selected in `td_bridge`:

- `qbx_garages`; or
- `qb_garages`.

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

## Garage provider boundary

TD-Housing never calls `qbx_garages` or `qb-garages` directly on the migrated garage path.

The owning character requests registration by property ID only. TD-Housing resolves the authoritative property and garage state server-side, verifies that the requesting character is the owner, and then calls:

```lua
TD.Garage.RegisterHouse(source, garageId, garageData)
```

QBox garage access uses the normalized character identifier allow-list through the bridge `canAccess` callback. QB Garages keeps its existing house-garage lifecycle behind bridge capabilities.

Garage provider selection belongs in `td_bridge`, for example:

```lua
Config.Providers.garage = 'qbx_garages'
```

or:

```lua
Config.Providers.garage = 'qb_garages'
```

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

Adjust provider names to the server configuration. If `td_bridge` is configured to depend on a provider category, the selected provider must already be available when that capability is used.

## Development status

The TrueDane 3.0 server boundary is active for ownership, access, property capabilities and Realtor property mutations.

The migrated runtime now covers framework/player state, notifications, target/radial interactions, inventory/stash state, MLO door lifecycle and property garages through `td_bridge`.

The remaining migration debt is primarily inside the inherited Housing runtime:

- legacy `ps-housing:*` client event namespace;
- legacy Housing NUI source;
- final provider-neutral migration of spawn, weather and character-creation/clothing compatibility.

These internal compatibility surfaces must not be copied into new TrueDane code.

## CI

The repository CI currently verifies:

- StyLua formatting for migrated TrueDane Lua;
- Lua 5.4 syntax for migrated files;
- migrated runtime provider-boundary rules, including rejection of direct garage-provider calls;
- server-side garage ownership validation on the migrated registration path;
- property capability tests;
- property capability service tests, including stable stash IDs and safe removal;
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
9. verify a non-empty stash cannot be removed;
10. verify stash contents remain attached to the same furniture after restart/reordering;
11. wardrobe placement/use;
12. furniture modes `player`, `fixed` and `disabled`;
13. owner garage registration/use with the selected garage provider;
14. verify a non-owner cannot register another property's garage;
15. `RegisterProperty`;
16. `SetOwner`;
17. `UpdateShell`;
18. `UpdateGarage`;
19. `UpdateImages`;
20. access grant/revoke persistence;
21. restart persistence after mutations;
22. TD-Realtor sale ownership transfer;
23. TD-Realtor rental start/end flow.

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
