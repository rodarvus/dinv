# CLAUDE.md — dinv

## Overview

**dinv** is a comprehensive inventory management plugin for Aardwolf MUD, running inside MUSHclient. Forked from Durel's aard_inventory (v2.0056), this fork (v3.x) has been significantly modernized: SQLite storage, modular Lua architecture, schema migrations, manifest-based updates, numerous bug fixes, and a migration tool for importing old data.

- **Repository:** github.com/rodarvus/dinv (canonical; always use `-R rodarvus/dinv` with `gh`)
- **Plugin ID:** 731f94b0f2b54345f836bbaf
- **Language:** Lua embedded in XML
- **Authors:** Durel (original), Rodarvus (fork)

## Architecture

### File Structure

| File | Purpose |
|------|---------|
| `dinv.xml` | Plugin bootstrap: aliases, triggers, script loader. Contains `version` attribute that must match changelog. |
| `dinv.manifest` | Update system manifest: `plugin_version` + per-file version numbers. |
| `dinv.changelog` | User-facing changelog (Lua table format). |
| `dinv_init.lua` | Initialization, config system (save/load/reset), version management. |
| `dinv_db.lua` | SQLite database layer, schema creation, migrations, transaction wrapper. |
| `dinv_dbot.lua` | Core framework: command execution, callbacks, GMCP helpers, prompt handling. |
| `dinv_cli.lua` | All CLI command handlers, usage text, and examples. |
| `dinv_items.lua` | Item management: refresh, identify, search, get/put, organize. |
| `dinv_data.lua` | Static data tables: wear locations, item types, stat definitions. |
| `dinv_cache.lua` | Item caching (recent, frequent, custom). |
| `dinv_priority.lua` | Priority profiles: stat weights for equipment scoring. |
| `dinv_score.lua` | Equipment scoring engine. |
| `dinv_set.lua` | Equipment set builder: finds optimal gear combinations. |
| `dinv_equipment.lua` | Wear/remove operations and conflict resolution. |
| `dinv_statbonus.lua` | Stat bonus calculations (class, race, tier, etc.). |
| `dinv_analyze.lua` | Equipment analysis and comparison. |
| `dinv_consume.lua` | Consumable management: buy, use, auto-organize. |
| `dinv_portal.lua` | Portal item management. |
| `dinv_regen.lua` | Regen mode (auto-sleep for HP/mana recovery). |
| `dinv_report.lua` | Equipment reporting. |
| `dinv_tags.lua` | Async operation tagging and completion tracking. |
| `dinv_usage.lua` | Display helpers for formatted output. |
| `dinv_migrate.lua` | Migration tool: imports old aard_inventory state files into SQLite. |

### Storage

- **Database:** `{pluginStatePath}/{characterName}/dinv.db` (SQLite)
- **Backups:** `{pluginStatePath}/{characterName}/backup/{name}-{timestamp}.db`
- **Config:** SQLite `config` table (key-value, keys prefixed `config.`)
- **Schema migrations:** tracked in `migrations` table

### Key Patterns

- **Async operations:** `wait.make(coroutineFunction)` for non-blocking MUD interaction
- **Command execution:** `dbot.execute.fast.command()` (no echo), `dbot.execute.safe.blocking()` (with timeout)
- **Transactions:** `dinv_db.transaction(function() ... end)` for atomic DB writes
- **Config access:** `inv.config.table.fieldName` at runtime; `inv.config.save()` to persist
- **Tags:** `inv.tags.new(line)` / `inv.tags.stop()` for tracking async completion

## Development Workflow

### Before Every Change

1. **Enter plan mode** — use plan mode to explore the codebase and design the implementation approach.
2. **Present the plan** — describe what will change, why, and show the affected code. Wait for explicit approval.
3. **No changes without permission** — this is a hard requirement, no exceptions.

### Every Change Must Include

1. **Changelog entry** in `dinv.changelog`:
   - Format: `dbot.changelog[X.YYYY] = { { change = drlDbotChangeLogTypeXxx, desc = [[...]] } }`
   - Types: `drlDbotChangeLogTypeFix` (bug fix), `drlDbotChangeLogTypeNew` (feature), `drlDbotChangeLogTypeMisc` (other)
2. **Version attribute** in `dinv.xml` `<plugin>` tag must match the new changelog version
3. **Manifest update** in `dinv.manifest`: bump `plugin_version` and version numbers for all changed files

### Version Numbering

- **3.x series** (forked from Durel's 2.x)
- Increment by 1 from the previous version (e.g., 3.0073 → 3.0074)

### Git Commits

- Small, self-contained, atomic commits — one logical change per commit
- Each commit should be independently reviewable and suitable as a standalone upstream PR
- Never bundle unrelated changes

### Releases

1. Draft release notes matching prior release style (`gh release list -R rodarvus/dinv`)
2. Review notes with user before proceeding
3. Create annotated tag: `git tag -a v3.XXXX -m "..."`
4. Push: `git push origin master && git push origin v3.XXXX`
5. Create GitHub release: `gh release create v3.XXXX -R rodarvus/dinv --title "..." --notes "..."`

### Backward Compatibility

Not a goal. The fork has diverged significantly (new plugin ID, SQLite, modularization). Instead, provide clean migration via `dinv migrate`. Old state files are never modified.
