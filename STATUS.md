# dinv - Status and Roadmap

**Version:** 3.0047  
**Authors:** Durel, Rodarvus  
**Repository:** https://github.com/rodarvus/dinv  
**Forked from:** https://github.com/Aardurel/aard-plugins (v2.0056, dormant since Nov 2020)

## Overview

dinv is a comprehensive inventory management plugin for Aardwolf MUD, running on MUSHclient. It was forked from Durel's aard_inventory and has been significantly modernized with a modular codebase, SQLite-backed storage, and numerous bug fixes and improvements.

## Completed Work (v3.0001–v3.0047)

### Phase 1: Bug Fixes and Features
- **v3.0001:** Fixed crash in `searchIdsCSV()`
- **v3.0002:** Fixed incorrect equipment rankings with fractional priority weights
- **v3.0003:** Added hammerswing as a priority-eligible pseudo-stat
- **v3.0004:** Renamed from aard_inventory to dinv with new plugin ID

### Phase 2: Modularization
- **v3.0005:** Extracted 23K-line monolith into 19 separate `.lua` files

### Phase 3: SQLite Migration
- **v3.0006–v3.0015:** Migrated all 14 state files to single SQLite database
- **v3.0016–v3.0019:** Performance fixes (transactions, lazy-load, incremental saves)
- **v3.0020–v3.0022:** Dead code cleanup, backup rewrite, window flash fix

### Bug Fixes and Code Quality
- **v3.0023:** Fixed note mode compatibility (upstream issues #3/#7)
- **v3.0024–v3.0029:** Fixed objectLocation type mismatch, undefined error constants, variable typo, missing organize field, global leaks, consume bugs
- **v3.0030:** Removed ~300 lines of dead code

### Search and Performance
- **v3.0031–v3.0033:** Incremental saves during identification, SQL consume counts, consume shorthand
- **v3.0034–v3.0035:** Alias fixes for consume and backup
- **v3.0036:** Fixed items not returning to organized containers
- **v3.0037–v3.0038:** Hybrid SQL+Lua search, SQL pre-filtering for set creation
- **v3.0039:** Organize overlap detection

### Consume Module Improvements
- **v3.0040:** Fixed hardcoded objId collision risk
- **v3.0041–v3.0045:** Buy feedback, restock tips, cap warning, Food type support, completion feedback

### Identification Improvements
- **v3.0046:** Items show correct type immediately after discovery
- **v3.0047:** Failed identifications no longer marked as "full"

## Upstream Issues Resolution

| Issue | Title | Status |
|-------|-------|--------|
| #2 | Intermittent file I/O error | **Resolved** — SQLite replaces fragile serialized Lua format |
| #3 | Timer/Trigger error after note | **Fixed** in v3.0023 |
| #6 | Rearrange documentation | **Open** — low priority |
| #7 | Soft error exiting note mode | **Fixed** in v3.0023 |
| #8 | Reload crash in getCurrentDir | **Resolved** — function removed |
| #9 | Fractional priority rounding | **Fixed** in v3.0002 |

## Architecture

```
dinv.xml              (690 lines)   XML structure + bootstrap
dinv_init.lua         (935 lines)   Plugin info, deps, callbacks, inv.init/version/config
dinv_db.lua           (780 lines)   SQLite infrastructure, schema, helpers, search
dinv_dbot.lua       (3,300 lines)   dbot.* utility framework
dinv_cli.lua        (3,510 lines)   Command-line interface
dinv_items.lua      (5,830 lines)   Item management core
dinv_data.lua         (385 lines)   Constants and field definitions
dinv_cache.lua        (585 lines)   Item caching (recent + custom)
dinv_priority.lua   (1,960 lines)   Equipment priorities
dinv_score.lua        (235 lines)   Item/set scoring
dinv_set.lua        (1,740 lines)   Equipment sets
dinv_equipment.lua    (390 lines)   Weapons + snapshots
dinv_statbonus.lua    (695 lines)   Stat bonus tracking
dinv_analyze.lua      (308 lines)   Set analysis across levels
dinv_usage.lua        (250 lines)   Item usage tracking
dinv_tags.lua         (330 lines)   Command completion tags
dinv_consume.lua      (745 lines)   Consumable items
dinv_portal.lua       (178 lines)   Portals + area passes
dinv_regen.lua        (278 lines)   Auto-wear regen ring
dinv_report.lua        (93 lines)   Channel reporting
```

## Storage

- Single SQLite database per character
- DELETE journal mode, explicit transactions
- Lazy-loaded equipment sets
- Incremental saves during identification and single-item operations
- Schema migration framework
- Backup via .db file copies with pre-build auto-backup

## Remaining (Low Priority)

- **Migration tool** — Import old aard_inventory state files (deferred until stable)
- **Documentation reorganization** (issue #6)
