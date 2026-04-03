# dinv - Development Status

**Version:** 3.0068  
**Authors:** Durel, Rodarvus  
**Repository:** https://github.com/rodarvus/dinv

## Current State

All planned work is complete. The plugin has been fully modernized from the original aard_inventory (v2.0056, dormant since 2020) through 68 versions of improvements.

## What Changed Since the Fork

- **Modularization:** 23K-line monolith split into 19 Lua modules
- **SQLite storage:** All 14 state files replaced by single SQLite database per character
- **Performance:** Explicit transactions, lazy-loaded sets, SQL pre-filtering, incremental saves
- **Backup system:** Rewritten for SQLite (.db file copies, pre-build auto-backup)
- **Update system:** Manifest-based incremental updates with file add/modify/remove support
- **Bug fixes:** All 6 upstream issues resolved, 20+ additional pre-existing bugs fixed
- **New features:** Hammerswing stat, consume shorthand, Food type, organize overlap detection, completion feedback
- **Code quality:** ~600 lines of dead code removed, global variable leaks fixed, error constants corrected
- **Documentation:** Complete README rewrite, updated help text, LICENSE updated

## All Upstream Issues

| Issue | Status |
|-------|--------|
| #2 Intermittent file I/O error | **Resolved** — SQLite |
| #3 Timer/Trigger error after note | **Fixed** v3.0023 |
| #6 Documentation reorganization | **Fixed** v3.0066 |
| #7 Soft error exiting note mode | **Fixed** v3.0023 |
| #8 Reload crash in getCurrentDir | **Resolved** — removed |
| #9 Fractional priority rounding | **Fixed** v3.0002 |

## Remaining

- **Migration tool** — Import old aard_inventory state files (deferred until needed)
- **GitHub release** — Create first tagged release for distribution
