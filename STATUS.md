# dinv - Status and Roadmap

**Version:** 3.0033  
**Authors:** Durel, Rodarvus  
**Repository:** https://github.com/rodarvus/dinv  
**Forked from:** https://github.com/Aardurel/aard-plugins (v2.0056, dormant since Nov 2020)

## Overview

dinv is a comprehensive inventory management plugin for Aardwolf MUD, running on MUSHclient. It was forked from Durel's aard_inventory and has been significantly modernized with a modular codebase, SQLite-backed storage, and numerous bug fixes.

## Completed Work (v3.0001–v3.0033)

### Phase 1: Bug Fixes
- **v3.0001:** Fixed crash in `searchIdsCSV()` — nil parameter passed to `isSearchRelative()`
- **v3.0002:** Fixed incorrect equipment rankings with fractional priority weights
- **v3.0003:** Added hammerswing as a priority-eligible pseudo-stat

### Phase 1.5: Plugin Identity
- **v3.0004:** Renamed from aard_inventory to dinv with new plugin ID, updated author and URLs

### Phase 2: Modularization
- **v3.0005:** Extracted 23K-line monolith into 19 separate `.lua` files

### Phase 3: SQLite Migration
- **v3.0006–v3.0015:** Migrated all 14 state files to single SQLite database
- **v3.0016–v3.0017:** Fixed missing affectMod columns and spells field serialization
- **v3.0018–v3.0019:** Performance: transactions, lazy-load sets, optimized row parsing, incremental saves
- **v3.0020:** Removed old file-based storage dead code
- **v3.0021:** Rewrote backup system (.db file copies, pre-build auto-backup)
- **v3.0022:** Fixed console window flash on reload

### Bug Fixes and Code Quality
- **v3.0023:** Fixed note mode compatibility (upstream issues #3/#7)
- **v3.0024:** Fixed objectLocation type mismatch after SQLite load
- **v3.0025:** Fixed 10 undefined error constant references
- **v3.0026:** Fixed variable name typo in inv.reset()
- **v3.0027:** Added missing "organize" field to SQLite schema with migration
- **v3.0028:** Fixed global variable leaks (5 variables)
- **v3.0029:** Fixed consume module bugs (undefined globals, wrong error field)
- **v3.0030:** Removed ~300 lines of dead code

### Improvements
- **v3.0031:** Incremental saves during item identification (crash resilience)
- **v3.0032:** SQL-powered consume display counts (replaced O(N*M) loop)
- **v3.0033:** Consume shorthand — `dinv consume <type>` defaults to "big"

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
dinv_init.lua         (935 lines)   Plugin info, deps, callbacks, inv.init/version/config
dinv_db.lua           (680 lines)   SQLite infrastructure, schema, helpers
dinv_dbot.lua       (3,300 lines)   dbot.* utility framework
dinv_cli.lua        (3,500 lines)   Command-line interface
dinv_items.lua      (5,800 lines)   Item management core
dinv_data.lua         (385 lines)   Constants and field definitions
dinv_cache.lua        (585 lines)   Item caching (recent + custom)
dinv_priority.lua   (1,960 lines)   Equipment priorities
dinv_score.lua        (228 lines)   Item/set scoring
dinv_set.lua        (1,720 lines)   Equipment sets
dinv_equipment.lua    (390 lines)   Weapons + snapshots
dinv_statbonus.lua    (695 lines)   Stat bonus tracking
dinv_analyze.lua      (308 lines)   Set analysis across levels
dinv_usage.lua        (250 lines)   Item usage tracking
dinv_tags.lua         (355 lines)   Command completion tags
dinv_consume.lua      (725 lines)   Consumable items
dinv_portal.lua       (178 lines)   Portals + area passes
dinv_regen.lua        (278 lines)   Auto-wear regen ring
dinv_report.lua        (93 lines)   Channel reporting
```

## Storage

- Single SQLite database per character at `{pluginStatePath}/{characterName}/dinv.db`
- DELETE journal mode (no WAL)
- Explicit transactions for all bulk saves
- Lazy-loaded equipment sets (deferred until first access)
- Incremental saves for single-item operations during identification
- Schema migration framework for future changes

## Roadmap

### Medium Effort (next priorities)
- **Hybrid SQL+Lua search** — SQL pre-filter for level/type/name, Lua for complex queries
- **SQL pre-filtering for set creation** — Query eligible items instead of full table scan
- **Organize overlap detection** — Warn on conflicting container queries
- **Normalize offhandDam** — Fix case-sensitivity kludge in priority fields
- **Consolidate display helpers** — Extract shared name/ID formatting code

### Large Effort (future)
- **Full SQL search engine** — Translate entire query to SQL
- **Item score caching** — Precompute scores for analyze mode
- **Partial refresh** — Support maxNumItems parameter with incremental saves
- **Consume module overhaul** — Purchase verification, Food type, low-stock warnings

### Deferred
- **Migration tool** — Import old aard_inventory state files into SQLite
- **Documentation reorganization** (issue #6) — Restructure to lead with high-impact features
