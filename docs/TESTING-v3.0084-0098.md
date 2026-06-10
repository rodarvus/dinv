# dinv v3.0084–v3.0095 manual test suite

This document validates the 12-commit persistence-correctness pass landed on
2026-05-18. Each test is self-contained; you can run them in any order. Tests
are organised top-down by impact, then by regression risk at the end.

Pre-flight: open MUSHclient on the character you normally test with, then
`/reload` the dinv plugin and run `dinv` (no args) to confirm version
**3.0095** is loaded. Several tests need you to force-quit MUSHclient
(Task Manager → End Task on `mushclient.exe`) to validate crash recovery —
clean disconnect (`/quit`) is NOT the same and will mask the bugs.

For tests that reference a "fresh test character" or "a consumable you've
never owned": pick something you actually don't have, so nothing in
SQLite/cache pre-satisfies the test. A common safe choice is the level-1
heal "light relief" from the Aylor potion shop, but if you regularly carry
those then pick a less common consumable.

Throughout: ✅ = pass, ❌ = fail, ⚠️ = unexpected but maybe OK.

---

## Section 1 — Critical persistence fixes

### T1. v3.0086 — invmon stubs persist with refresh off (C3 + L7)
**The bug:** With `refreshEagerSec=0` (your default), brand-new items from
invmon were never saved to disk and disappeared on the next reload.

1. Confirm eager refresh is off: `dinv config refreshEagerSec` should show 0.
2. Pick a consumable you don't currently own and have **not** previously
   `consume add`ed this session. If unsure, run
   `dinv consume add heal "light relief"`, wait for it to complete, then
   `/reload` the plugin to wipe the in-memory cache.
3. `dinv consume buy heal 5` (or substitute your chosen type). Wait for the
   purchase to complete and the items to land in inventory/your auto-organize
   container.
4. `dinv consume display heal` — should show **5** of light relief. ✅
5. `/reload` the plugin.
6. `dinv consume display heal` again — should still show **5**. ✅
   - ❌ Before this fix: showed **0** after reload (stubs lived only in memory).

### T2. v3.0088 — recent/frequent/custom caches survive crashes (C1)
**The bug:** Cache mutations only persisted at clean disconnect. A crash
(or kill MUSHclient) lost the session's cache work.

1. Run `dinv key 1.bag mainbag` (or similar — pick any item you own, assign a
   custom keyword).
2. Confirm the keyword: `dinv search keyword mainbag` should match.
3. **Force-quit MUSHclient via Task Manager.** Do NOT use `/quit`.
4. Reopen MUSHclient and the same character.
5. `dinv search keyword mainbag` — should still match the same item. ✅
   - ❌ Before this fix: keyword was lost (custom cache only saved on fini).

### T3. v3.0089 — interrupted `set wear` doesn't wipe priority (C5 + H2)
**The bug:** `inv.set.create` nilled the level entry before the async
recompute. If interrupted, the next save did `DELETE FROM sets` and the row
was gone forever.

Quickest validation:
1. Pick a priority that has analyzed sets for your current level. If you
   don't have any, run `dinv analyze create mage 1 200` (or whichever
   priority + small range you can complete in under a minute).
2. Confirm: `dinv analyze list` shows the priority as "complete" (green).
3. `dinv set wear <priority>` — wait for it to complete.
4. `/reload` the plugin.
5. `dinv analyze list` — the priority should still be complete (green), not
   "partial" (yellow) with missing levels. ✅
   - ❌ Before this fix: an interrupted `set wear` would have removed the
     just-recomputed level from disk.

Bonus check for the H2 half (sets now persist immediately):
6. `dinv set wear <priority> <some level you have items for>`.
7. `/reload`.
8. `dinv unused` — items the just-worn set used should NOT appear as unused. ✅
   - ❌ Before this fix: unused flagged worn items because the computed set
     never reached disk.

### T4. v3.0090 — backup captures current state (C4)
**The bug:** `dinv backup create` closed the DB and copied the file without
flushing in-memory mutations first. The backup was strictly older than
what was on screen.

1. Note a current state — e.g., `dinv consume display heal` count, or
   `dinv search keyword mainbag` matches.
2. Make a mutation that's likely to be in-memory only — e.g.,
   `dinv consume add heal "light relief"` then immediately move on (don't
   wait for fini). The frequent cache add is now per-mutation thanks to
   v3.0088, so this isn't a perfect test. A stronger test: change a
   non-trivial config like `dinv config refreshEagerSec 30`.
3. `dinv backup create test`.
4. Change the config back: `dinv config refreshEagerSec 0`.
5. `dinv backup restore test` — confirm with `y` if prompted.
6. `dinv config refreshEagerSec` — should show **30** (the value at backup
   time), not **0**. ✅
   - ❌ Before this fix: restore would silently give the older state.

### T5. v3.0091 — `weapon next` cycles correctly across reload (H1)
**The bug:** `weapon use` and `weapon next` mutated weaponSet priority
exclusions in memory only; on reload the priority was stale.

1. Run `dinv weapon mage acid` (or any priority + damtype).
2. `dinv weapon next` once. Note which damtype the weapon you're now wielding
   is (`look <weapon>` or `dinv unused` will tell you indirectly).
3. `/reload` the plugin.
4. `dinv weapon next` again — should advance to a **further** damtype, not
   cycle back to acid (which step 1 already excluded). ✅
   - ❌ Before this fix: would start fresh because the disk priority had no
     exclusions recorded.

### T6. v3.0085 — SQL items fallback when frequent cache misses (B)
**The bug:** Even with cache persisted, an item pruned from the frequent
cache had no fallback. Identification was lost.

1. `consume add` two items of the same type but different levels so the
   frequent cache has both: e.g., `dinv consume add heal "light relief"`
   and `dinv consume add heal "serious relief"`.
2. `/reload` the plugin.
3. `dinv consume buy heal 5` (will buy the highest-level one you can use).
4. `dinv consume display heal` — should show the bought items with their
   actual count, not 0. ✅ Combined with T1, this confirms the full chain.

### T7. v3.0087 — bulk `consume remove` persists (C6)
**The bug:** `dinv consume remove <type>` with no item name nilled the
type in memory but didn't save.

1. Confirm a type exists: `dinv consume display heal` should list at least
   one entry.
2. `dinv consume remove heal` — should print
   `Removed all "heal" consumables from consumable table` (v3.0096 fix).
3. `dinv consume display heal` — should show no entries. ✅
4. `/reload` the plugin.
5. `dinv consume display heal` — should still show no entries. ✅
   - ❌ Before this fix: the type came back on reload.

(After validating, re-add the type so you don't lose it permanently:
`dinv consume add heal "light relief"`.)

---

## Section 2 — Schema / migration tests

### T8. v3.0092 — affectMod columns migration (M5)
**The bug:** A database created between v3.0006 and v3.0015 was missing
10 affectMod columns; identify-time INSERTs silently failed.

You almost certainly don't have a pre-v3.0016 database to test the
migration on, but you can confirm the migration mechanism still works on
your current DB:

1. `dinv backup create pre-m5-test`.
2. In the dinv state directory (`{plugin state path}/{character name}/`),
   open `dinv.db` with the SQLite CLI: `sqlite3 dinv.db`.
3. `SELECT version, description FROM migrations ORDER BY version;` — should
   list rows for versions 1, 2, **3** ("Backfill affectMod columns…"). ✅
4. `PRAGMA table_info(items);` and confirm columns `sanctuary`, `haste`,
   `flying`, `invis`, `regeneration`, `detectinvis`, `detecthidden`,
   `detectevil`, `detectgood`, `detectmagic` all exist on **items** and
   on **cache_recent**. ✅
5. Exit sqlite3 (`.quit`).

If you happen to have an old DB from before v3.0016 lying around:
6. Restore it: drop it in place of `dinv.db`, `/reload` the plugin.
7. Open the new DB in sqlite3 and verify the affectMod columns now exist
   and the migrations row 3 is recorded.

### T9. v3.0084 — cache_frequent table exists
1. `sqlite3 dinv.db`.
2. `.schema cache_frequent` — should return the CREATE TABLE statement. ✅
3. `SELECT cache_key, level, type FROM cache_frequent LIMIT 5;` — after
   you've used `consume add` or had a few invitem cache misses re-fill it,
   this should return rows. ⚠️ Empty is fine if nothing has populated it
   yet this session.

---

## Section 3 — Cleanup-pass validations

### T10. v3.0093 — refresh no longer does a config save (L1)
This is best validated by running with SQL logging if you have it; without
that, the test is "nothing breaks":
1. `dinv refresh all` and confirm it completes normally.
2. `dinv build confirm` (this DOES need a config save, now landed at the
   mutation site in build itself) and confirm it completes.
3. Both should succeed without error. ✅

### T11. v3.0094 — transaction rollback on Lua error (M4)
Pure defensive change; no current caller throws. The test is "nothing
breaks during normal use," which the rest of this suite validates as a
side effect. ✅ (implicit).

### T12. v3.0095 — itemIdEnd save (M1)
Hard to trigger the timeout case deliberately. The fix is mostly invisible
on the happy path because identifyCR was already saving. To at least
exercise the identify path:
1. Pick an item with `dinv identify level` showing "none" or partial. If
   you don't have one, drop and pick up an item.
2. Run a refresh (`dinv refresh`).
3. After refresh completes, `dinv show <objId>` of the item — should now
   show full identification. ✅

### T13. v3.0096 — bulk consume remove now prints a confirmation
1. Confirm a type exists: `dinv consume display heal`.
2. `dinv consume remove heal` — should print
   `Removed all "heal" consumables from consumable table`. ✅
3. Re-add to keep your list intact:
   `dinv consume add heal "light relief"`.

### T14. v3.0097 — stat-bonus estimates no longer pollute spellBonus (H5)
**The bug:** `inv.statBonus.get` lazy-seeded `spellBonus[level]` with the
estimate-table value on first use. `setCR` later weighted-averaged real
measurements against the estimate as if it were a prior real sample.

You'll need a SQLite CLI shell against `dinv.db` for the cleanest check.

1. `dinv reset statBonus` (or pick a level you've never been at — see
   alternative below). Note: this wipes existing measurements, so only
   run it if you don't mind re-accumulating them.
2. Pick a level you're not currently at and have no prior measurement
   for. Easy choice: a level far above your current (e.g., 200 if you're
   level 10), or far below.
3. `dinv set wear <priority> <level>` — this triggers an
   `inv.statBonus.get(level, ave)` call internally.
4. Open the DB: `sqlite3 dinv.db`.
5. `SELECT * FROM stat_bonuses WHERE bonus_type='spell' AND level = <level>;`
   — should return **0 rows**. ✅
   - ❌ Before this fix: would have returned one row per stat (str, int,
     wis, dex, con, luck), each with the estimate as `ave_val` and 0 as
     `max_val`.
6. `SELECT * FROM stat_bonuses WHERE bonus_type='equip';` — should return
   **0 rows** for any level. ✅
   - ❌ Before this fix: equipBonus values were persisted on every save.
7. Run `dinv set wear <priority> <your current level>` (a level where
   setCR has actually measured spell bonuses). Reopen sqlite3 and run
   `SELECT * FROM stat_bonuses WHERE bonus_type='spell' AND level = <current>;`
   — should return real measurements (non-zero max_val likely). ✅

Alternative (no SQLite CLI):
1. After step 3 above, run `dinv reload` (which calls fini → save).
2. Compare `dinv.db` file mtime/size before and after a level-200
   `dinv set` versus a current-level `dinv set`. The level-200 case
   should NOT grow the stat_bonuses table; current-level should.

### T15. v3.0098 — Consumables in containers survive death

**The bug:** A bag full of potions dropped on death came back empty in
dinv's view; only `dinv refresh all` recovered the contents.

You'll need to actually die for this. Pick a low-risk way (low-level
mob you can't kill, leeroy a CR area, whatever).

1. Put 3-5 frequent-cache consumables (healing potions are easiest)
   into a bag.
2. Verify they're tracked: `dinv consume display heal` should show
   the count, and `dinv search heal in <bag-keyword>` (or whatever
   query you use to see container contents) should list them.
3. Die.
4. Retrieve your corpse contents the normal way (get all corpse, or
   the equivalent if you're using a death-recovery alias).
5. Without running `dinv refresh all`, run `dinv consume display
   heal` — the count should match what you had before death. ✅
6. As a stronger check, `dinv consume heal small 1` — should
   actually quaff a potion from the bag.
   - ❌ Before this fix: count showed 0, quaff said "no items
     available," `dinv refresh all` was the only recovery.

Bonus regression check (combines with T14's known-gap caveat): the
direct-inventory and non-consumable-bag death cases were already
expected to work via v3.0086 + v3.0088 + v3.0081, but neither has had
an explicit in-game test. While you're dead anyway:
* Drop a few non-consumable items directly to your corpse, retrieve,
  confirm they show up in `dinv search` immediately.
* Put non-consumable gear (no potions) into a bag, drop the bag,
  retrieve, confirm the contents come back via `dinv show <bag>`.

---

## Section 4 — Regression tests (the things that should still work)

Quick exercise of common workflows to catch any unintended changes.

### R1. Buy / quaff / display loop
1. `dinv consume buy heal 5` — buys 5.
2. `dinv consume display heal` — count = 5. ✅
3. `dinv consume heal 3` — quaff 3.
4. `dinv consume display heal` — count = 2. ✅
5. `dinv consume heal 5` — should warn that only 2 are available and quaff
   those, or buy more depending on your config. Behaviour should be sane.

### R2. Container moves
1. Pick any item; note its container (`dinv show <objId>`).
2. `get <item>` and `put <item> 2.bag` (or any container).
3. `dinv show <objId>` — confirms new container. ✅
4. `/reload`.
5. `dinv show <objId>` — should still show the new container. ✅

### R3. Wear / remove
1. `wear <item>` (any item not currently worn).
2. `dinv show <objId>` — should show worn at the correct slot. ✅
3. `remove <item>`.
4. `dinv show <objId>` — should show in inventory.
5. `/reload`.
6. `dinv show <objId>` — should still show in inventory. ✅

### R4. Refresh / build
1. `dinv refresh` — should complete without errors.
2. `dinv refresh all` — should complete without errors.
3. (Only if you're prepared to wait a few minutes) `dinv build confirm`
   — should complete; afterwards `dinv` should report status. ✅

### R5. Set display / wear
1. Pick a priority with analyzed data: `dinv analyze list`.
2. `dinv set display <priority>` — should print the set.
3. `dinv set wear <priority>` — should wear it.
4. `dinv unused` — items the set just worn should NOT appear. ✅
5. `/reload`.
6. `dinv unused` — items still should NOT appear. ✅ (validates T3 H2 half).

### R6. analyze create — happy path
1. Pick a priority and a small level range. `dinv analyze create mage 1 50`.
2. Wait for completion (a minute or two depending on inventory size).
3. `dinv analyze list` — mage should show as complete in green. ✅
4. `/reload`.
5. `dinv analyze list` — still complete. ✅

### R7. analyze create — interrupted
1. `dinv analyze create mage 1 200` (large range).
2. **Force-quit MUSHclient via Task Manager** mid-analysis (you can watch
   the level progress in the output and kill it around level 100).
3. Reopen MUSHclient, same character.
4. `dinv analyze list` — should show mage as **partial** (yellow), not
   missing entirely. ✅
5. The completed levels (1..approx 100) should be preserved on disk; you
   can verify with sqlite3:
   `SELECT priority_name, level FROM sets WHERE priority_name='mage' ORDER BY level;`
   — should list all completed levels, not be empty. ✅
   - ❌ Before v3.0089: an interrupted analyze could wipe all set rows.

### R8. weapon use / next round-trip
1. `dinv weapon mage acid` — should wield + wear the set.
2. `dinv weapon next` — should rotate to a non-acid weapon.
3. Repeat `dinv weapon next` until you exhaust available damtypes.
4. Confirm no spurious priority-related errors in any step. ✅

### R9. Custom keyword + organize query
1. `dinv key <item> testkw` — adds a custom keyword.
2. `dinv search keyword testkw` — should match. ✅
3. `dinv organize 2.bag testkw` (or similar — assign a query to a
   container).
4. Confirm it works: `dinv organize` shows the new query.
5. `/reload`.
6. Both the keyword and the organize query should still be present. ✅
7. Cleanup: `dinv key <item> testkw remove`,
   `dinv organize 2.bag clear`.

### R10. Backup roundtrip
1. `dinv backup list` — shows existing backups.
2. `dinv backup create pre-test-suite`.
3. Do a few mutations (refresh, set wear, whatever).
4. `dinv backup restore pre-test-suite` (confirm with `y`).
5. State should match the backup point. ✅
6. `dinv backup delete pre-test-suite`.

---

## Section 5 — Known gaps (not regressions)

These items from the audit were intentionally NOT fixed in this batch.
If you observe any of them, they are pre-existing, not introduced by
this work:

- **L2 / H6** — `inv.items.refreshCR`'s trailing wholesale `inv.items.save`
  is still load-bearing for orphan-prune cleanup and itemDataStats
  field updates. Replacing it with per-item saves would be cleaner but
  has subtle behavioural implications.
- **L3** — `inv.cache.add` will still cache None-identifyLevel items
  in the recent cache. Wastes a little cache space; no functional bug.

If you had pre-v3.0097 `spellBonus` data on disk that was seeded from
estimates (max_val all zeros, ave_val matches estimateTable), it will
stay in your DB and continue influencing weighted averages until setCR
overwrites it with enough real measurements. Run `dinv reset statBonus`
if you want a clean slate.

---

## If anything fails

1. Note which test, the step number, and what you observed.
2. `dinv` command output and any error lines from the output window are
   the most useful artefacts.
3. Don't `dinv reset` or otherwise destroy state without first capturing
   the failing state — `dinv backup create failure-<test-id>` first.
4. Then report back; we'll diagnose.
