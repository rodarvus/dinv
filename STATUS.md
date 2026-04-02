# dinv - Status and Roadmap

**Version:** 3.0023  
**Authors:** Durel, Rodarvus  
**Repository:** https://github.com/rodarvus/dinv  
**Forked from:** https://github.com/Aardurel/aard-plugins (v2.0056, dormant since Nov 2020)

## Overview

dinv is a comprehensive inventory management plugin for Aardwolf MUD, running on MUSHclient. It was forked from Durel's aard_inventory and has been significantly modernized with a modular codebase and SQLite-backed storage.

## Completed Work (v3.0001–v3.0023)

### Phase 1: Bug Fixes
- **v3.0001:** Fixed crash in `searchIdsCSV()` — nil parameter passed to `isSearchRelative()`
- **v3.0002:** Fixed incorrect equipment rankings with fractional priority weights (score truncated to 2 decimal places)
- **v3.0003:** Added hammerswing as a priority-eligible pseudo-stat for hammer weapon builds

### Phase 1.5: Plugin Identity
- **v3.0004:** Renamed from aard_inventory to dinv with new plugin ID (`731f94b0f2b54345f836bbaf`), updated author and auto-update URLs

### Phase 2: Modularization
- **v3.0005:** Extracted all Lua code from the 23K-line monolithic XML into 19 separate `.lua` files. `dinv.xml` now contains only XML structure (aliases, triggers) and a single `dofile()` bootstrap.

### Phase 3: SQLite Migration
- **v3.0006–v3.0015:** Migrated all 14 serialized Lua state files to a single SQLite database per character. Tables: items, cache_recent, cache_custom, priorities, priority_blocks, sets, snapshots, consumables, stat_bonuses, config, migrations.
- **v3.0016:** Fixed missing affectMod columns (sanctuary, haste, flying, etc.)
- **v3.0017:** Fixed spells field serialization (nested table → string format)
- **v3.0018:** Wrapped all save operations in explicit transactions (critical performance fix)
- **v3.0019:** Lazy-load equipment sets, optimized row parsing, incremental item saves, schema migration framework
- **v3.0020:** Removed dead code from old file-based storage system (~195 lines)
- **v3.0021:** Rewrote backup system — .db file copies via Lua I/O, pre-build automatic backup, removed periodic/AFK auto-backups
- **v3.0022:** Fixed console window flash on reload (replaced `os.execute` with hidden shell)

### Bug Fixes
- **v3.0023:** Fixed note mode compatibility (upstream issues #3/#7) — `noteIsPending` flag now cleared when user sends any command

## Upstream Issues Resolution

| Issue | Title | Status |
|-------|-------|--------|
| #2 | Intermittent file I/O error loading config | **Resolved** — SQLite replaces fragile serialized Lua format |
| #3 | Timer/Trigger error after writing a note | **Fixed** in v3.0023 |
| #6 | Rearrange documentation | **Open** — planned for future |
| #7 | Soft error exiting note mode | **Fixed** in v3.0023 |
| #8 | Reload crash in getCurrentDir | **Resolved** — function removed in SQLite migration |
| #9 | Fractional priority rounding | **Fixed** in v3.0002 |

## Architecture

```
dinv.xml              (687 lines)   XML structure + bootstrap
dinv_init.lua         (940 lines)   Plugin info, deps, callbacks, inv.init/version/config
dinv_db.lua           (660 lines)   SQLite infrastructure, schema, helpers
dinv_dbot.lua       (3,600 lines)   dbot.* utility framework
dinv_cli.lua        (3,500 lines)   Command-line interface
dinv_items.lua      (5,800 lines)   Item management core
dinv_data.lua         (385 lines)   Constants and field definitions
dinv_cache.lua        (600 lines)   Item caching (recent + custom)
dinv_priority.lua   (1,960 lines)   Equipment priorities
dinv_score.lua        (228 lines)   Item/set scoring
dinv_set.lua        (1,720 lines)   Equipment sets
dinv_equipment.lua    (390 lines)   Weapons + snapshots
dinv_statbonus.lua    (700 lines)   Stat bonus tracking
dinv_analyze.lua      (308 lines)   Set analysis across levels
dinv_usage.lua        (250 lines)   Item usage tracking
dinv_tags.lua         (380 lines)   Command completion tags
dinv_consume.lua      (730 lines)   Consumable items
dinv_portal.lua       (178 lines)   Portals + area passes
dinv_regen.lua        (306 lines)   Auto-wear regen ring
dinv_report.lua        (93 lines)   Channel reporting
```

## Storage

- Single SQLite database per character at `{pluginStatePath}/{characterName}/dinv.db`
- DELETE journal mode (no WAL)
- Explicit transactions for all bulk saves
- Lazy-loaded equipment sets (deferred until first access)
- Incremental saves for single-item operations
- Schema migration framework for future changes

## Roadmap

### Deferred (when codebase is stable)
- **Migration tool** — Import old aard_inventory state files into SQLite for users upgrading from the original plugin

### Planned Improvements
- **Documentation reorganization** (issue #6) — Restructure to lead with high-impact features
- **Code quality** — Consolidate duplicate code, modernize patterns, improve error handling
- **Spells field redesign** — Consider dedicated table for the only nested-table stat field
- **Build confirm identification** — Investigate flakiness where items are catalogued as "Unknown"
- **Further performance optimization** — Additional incremental save opportunities

### Future Features
- To be determined based on community feedback and usage patterns
