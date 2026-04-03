# dinv - Inventory Manager for Aardwolf MUD

dinv is a comprehensive inventory management plugin for [Aardwolf MUD](http://www.aardwolf.com/), running on [MUSHclient](http://www.gammon.com.au/mushclient/). It tracks all your items, optimizes equipment sets based on stat priorities, manages consumables, organizes containers, and more.

dinv is a modernized fork of Durel's [aard_inventory](https://github.com/Aardurel/aard-plugins), with a modular codebase, SQLite-backed storage, and numerous bug fixes and improvements.

## Quick Start

1. Download the latest release from [GitHub Releases](https://github.com/rodarvus/dinv/releases)
2. Extract the zip file into your MUSHclient `worlds/plugins/` directory (this creates a `dinv/` folder with all plugin files)
3. **Important:** If you have aard_inventory installed, you must **remove** it (not just disable) from your plugin list. dinv and aard_inventory cannot coexist.
4. In MUSHclient, install the plugin: File > Plugins > Add, navigate to `worlds/plugins/dinv/` and select `dinv.xml`
5. Connect to Aardwolf, go to a quiet room, and run: `dinv build confirm`
6. Wait approximately 5 minutes while dinv identifies all your items
7. You're ready! Type `dinv help` to see all commands.
8. (Recommended) Enable automatic identification of new items: `dinv refresh eager 5`. This ensures newly acquired items (bought, looted, received) are identified within seconds. Without this, you need to manually run `dinv refresh` after acquiring items.

## Key Features

### Equipment Optimization

The most powerful feature is automatic equipment set optimization. Define stat priorities, and dinv finds the best combination of items for every level:

```
dinv priority list                    -- See available priorities
dinv set wear psi-melee               -- Wear the optimal set for your level
dinv set display psi-melee 150        -- Preview what you'd wear at level 150
dinv analyze create psi-melee         -- Analyze optimal sets across all levels
```

### Inventory Search

Search your entire inventory with flexible queries:

```
dinv search type weapon               -- Find all weapons
dinv search minlevel 100 maxlevel 200 -- Find items in a level range
dinv search name sword                -- Find items with "sword" in the name
dinv search type armor || type shield -- Find armor OR shields
```

### Container Organization

Automatically sort items into containers based on rules:

```
dinv organize add bag minLevel 1 || maxLevel 291
dinv organize                         -- Move matching items to the bag
```

### Consumable Management

Track and use potions, pills, scrolls, and food:

```
dinv consume add heal potion          -- Register a heal consumable at a shop
dinv consume buy heal 5               -- Buy 5 heal potions
dinv consume heal                     -- Use the best heal potion for your level
dinv consume display                  -- See all consumables and stock levels
```

## Command Reference

### Inventory Table Access
| Command | Description |
|---------|-------------|
| `dinv build confirm` | Build the inventory table (first-time setup) |
| `dinv refresh [on \| off \| eager \| all]` | Refresh inventory data |
| `dinv search [objid \| full] <query>` | Search items |

### Item Management
| Command | Description |
|---------|-------------|
| `dinv get <query>` | Get items from containers to inventory |
| `dinv put <container> <query>` | Put items into a container |
| `dinv store <query>` | Return items to their home container |
| `dinv keyword [add \| remove] <keyword> <query>` | Tag items with custom keywords |
| `dinv organize [add \| clear \| display] <container> <query>` | Set up container organization rules |

### Equipment Sets
| Command | Description |
|---------|-------------|
| `dinv set [display \| wear] <priority> <level>` | Display or wear an equipment set |
| `dinv weapon [next \| <priority> <damTypes>]` | Switch weapons by damage type |
| `dinv snapshot [create \| delete \| list \| display \| wear] <name>` | Save/restore equipment snapshots |
| `dinv priority [list \| display \| create \| clone \| delete \| edit \| copy \| paste \| compare] <name>` | Manage stat priorities |

### Equipment Analysis
| Command | Description |
|---------|-------------|
| `dinv analyze [list \| create \| delete \| display] <priority> <positions>` | Analyze optimal sets across levels |
| `dinv usage <priority \| all> <query>` | Show which levels use an item |
| `dinv compare <priority> <relative name>` | Compare an item against current sets |
| `dinv covet <priority> <auction #>` | Evaluate an auction item |

### Consumables and Equipment
| Command | Description |
|---------|-------------|
| `dinv consume [add \| remove \| display \| buy \| small \| big \| <type>] <args>` | Manage consumable items |
| `dinv portal [use] <query>` | Use a portal |
| `dinv pass <pass ID> <seconds>` | Temporarily hold an area pass |

### Advanced Options
| Command | Description |
|---------|-------------|
| `dinv backup [list \| create \| delete \| restore] <name>` | Manage database backups |
| `dinv forget <query>` | Remove items from tracking (re-identified on next refresh) |
| `dinv migrate [confirm]` | Import data from old aard_inventory |
| `dinv notify [none \| light \| standard \| all]` | Set notification verbosity |
| `dinv regen [on \| off]` | Auto-wear regen ring when sleeping |
| `dinv reset [list \| confirm] <modules \| all>` | Reset plugin modules |
| `dinv cache [reset \| size] [recent \| frequent \| custom \| all]` | Manage item caches |
| `dinv tags <names \| all> [on \| off]` | Control command completion tags |
| `dinv reload` | Reload the plugin |

### Plugin Info
| Command | Description |
|---------|-------------|
| `dinv version [check \| changelog \| update confirm]` | Check for updates and view changelog |
| `dinv help <command>` | View detailed help for a command |
| `dinv report <channel> [item \| set] <args>` | Report items or sets to a channel |

## Installation

### Requirements
- [MUSHclient](http://www.gammon.com.au/mushclient/) (version 4.98 or later)
- An [Aardwolf MUD](http://www.aardwolf.com/) character

### Fresh Install
1. Download the latest release from the [releases page](https://github.com/rodarvus/dinv/releases)
2. Extract the zip file into your MUSHclient `worlds/plugins/` directory (rename the extracted folder to `dinv` if needed)
3. Open MUSHclient, go to File > Plugins > Add
4. Navigate to the `dinv` directory and select `dinv.xml`
5. Connect to Aardwolf and run `dinv build confirm` in a quiet room

### Removing aard_inventory

If you previously used aard_inventory (the original plugin by Durel), you must **remove** it before installing dinv:

1. In MUSHclient, go to File > Plugins
2. Select aard_inventory and click **Remove** (not just disable)
3. Install dinv as described above

dinv uses a different plugin ID and storage directory, so your old aard_inventory state files are completely safe and untouched. You can switch back to aard_inventory at any time by removing dinv and re-installing aard_inventory (the two plugins cannot be active at the same time).

## Upgrading from aard_inventory

dinv is a fork of aard_inventory with a new plugin identity. Your old aard_inventory data is safe:

- dinv uses a different plugin ID (`731f94b0f2b54345f836bbaf`)
- dinv stores data in a separate directory using SQLite
- Your old aard_inventory state files are never read or modified

### Migration tool

dinv includes a migration tool that imports your old aard_inventory data (items, priorities, equipment sets, consumables, stat bonuses, and config) into dinv's SQLite database. This avoids the need to rebuild your inventory from scratch.

```
dinv migrate                -- See what old data is available
dinv migrate confirm        -- Run the migration
```

**Important notes:**
- Migration **replaces all current dinv data** for the current character. A backup is created automatically before migration.
- Old aard_inventory state files are never modified. You can switch back at any time.
- Migration operates on the currently logged-in character only. If you have multiple characters, log into each one and run `dinv migrate confirm` separately.
- A tool to migrate from dinv back to aard_inventory is not provided. To revert, remove dinv and reinstall aard_inventory.

If you prefer to start fresh instead, run `dinv build confirm` to create a new inventory database from scratch.

## Updating

dinv can check for and install updates from GitHub:

```
dinv version check          -- Check if a newer version is available
dinv version changelog      -- View changes since your version
dinv version update confirm -- Download and install the latest version
```

Updates are incremental -- only changed files are downloaded. The update system uses a manifest file to track per-file versions, ensuring efficient and reliable updates.

## Backup System

dinv uses SQLite for storage, which provides crash-safe, atomic writes. Under normal operation, backups should not be necessary. However, the backup system is available as a safety net for peace of mind.

A backup is automatically created before `dinv build confirm` (if you have existing data). You can also manage backups manually:

```
dinv backup create mybackup  -- Create a named backup
dinv backup list             -- List all backups
dinv backup restore mybackup -- Restore a backup
dinv backup delete mybackup  -- Delete a backup
```

Backups are copies of the SQLite database file, stored in the plugin's backup directory.

## Known Limitations

1. **Enchanted items may cache old stats.** If you enchant an item, use `dinv forget <query>` to clear the old stats. The next refresh will pick up the new values.

2. **Setweight and scroll scribing** don't trigger automatic re-identification. Use `dinv forget <query>` after these operations.

3. **Wand and staff charges** are not updated in real-time as the item is used. The displayed charges may not reflect current reality.

4. **Closed containers** are not automatically opened. Keep your containers open for dinv to manage them.

5. **Tags and AFK mode.** If you go AFK during an operation, end tags may be delivered as notifications instead of echoes, which triggers cannot catch.

6. **Portal wish timing.** If you add the portal wish after building your inventory, run `dinv forget type portal` followed by `dinv refresh all`.

## Technical Details

### Storage
dinv uses a SQLite database (one per character) for all persistent data. This replaces the serialized Lua state files used by the original aard_inventory, eliminating the database corruption issues that plagued the old format.

### Architecture
The plugin is modularized into 19 Lua files loaded by a single XML bootstrap (`dinv.xml`). Each module handles a specific feature area (items, priorities, sets, cache, consume, etc.).

### Performance
- Equipment sets are lazy-loaded (only loaded from database when first accessed)
- Item searches use SQL pre-filtering for common criteria
- All bulk save operations use explicit SQLite transactions
- Individual item changes use incremental saves (INSERT OR REPLACE)

## Credits

- **Durel** (Aardurel) -- Original author of aard_inventory
- **Rodarvus** -- Fork maintainer, SQLite migration, modularization, bug fixes, and improvements
- **Arcidayne** -- Original plugin update system
- **jontsai** -- getItemIds external API ([PR #4](https://github.com/Aardurel/aard-plugins/pull/4))
- **Yajanofaard** -- Hammerswing feature proposal ([PR #10](https://github.com/Aardurel/aard-plugins/pull/10))
- **aardGigel** -- searchIdsCSV bug report ([PR #5](https://github.com/Aardurel/aard-plugins/pull/5))
- **fiendish** -- Bug reports and documentation feedback ([#6](https://github.com/Aardurel/aard-plugins/issues/6), [#7](https://github.com/Aardurel/aard-plugins/issues/7), [#8](https://github.com/Aardurel/aard-plugins/issues/8))
- **Vettir** -- Priority rounding bug report ([#9](https://github.com/Aardurel/aard-plugins/issues/9))
- **Thridi** -- Note mode bug report ([#3](https://github.com/Aardurel/aard-plugins/issues/3))
- **Mandrakx** -- Storage error report ([#2](https://github.com/Aardurel/aard-plugins/issues/2))

## License

MIT License. See [LICENSE](LICENSE) for details.
