# dinv 3.0127 — Proteles live test plan

Historical plan for the 3.0127 candidates. The user reported that focused Proteles testing through 3.0130 passed on October 17, 2026, and authorized committing the accumulated changes. Extended-session and MUSHclient validation remain pending. See the [validation record](VALIDATION-3.0127.md) for current acceptance and the historical build results below.

## What changed

Saved inventory loads after a fresh character identity arrives. Startup no longer waits for prompt/configuration replies or changes the server prompt. Inventory synchronization happens separately, using your existing automatic-refresh setting.

Game requests now have a single owner, deadline and cleanup path. Canceling or timing out a queued request prevents it from being sent later. Incomplete inventory snapshots and identification responses are discarded. Existing scoring, equipment selection, SQL schema and command syntax remain in use.

`dinv status` reports the version, saved-data readiness, synchronization state, active request, queued requests, workflow count, observed prompt and automatic-refresh setting. An unknown prompt is an observation state, not a reason to toggle it.

`dinv cancel` stops current and queued dinv work and discards unfinished captures. Commands already sent to the game can still finish. Periodic work resumes on its normal schedule; cancellation does not change your saved automatic-refresh preference. Use `dinv refresh off` as well if you want automatic refresh to remain off.

## September 16 candidate — test this correction first

This candidate is **source-only and uncommitted**. No Release app was built or installed for it. Build and install Proteles yourself from the updated checkout, then quit the old app fully and open your new build. Version 3.0127 is unchanged because this is another correction to the same unreleased candidate. A plugin reload in the old app cannot pick up the host change.

The vendored resources already contain this checkout. If your build flow regenerates or checks them, run from the Proteles repository with `DINV_SOURCE_DIR=/path/to/dinv` set. The reference submodule remains on the last accepted release; do not overwrite this candidate from that old pin.

Keep recording on and note the start time of each step. Use familiar routes in a safe area and your existing equipment sets.

1. **Startup during ordinary play (two reconnects).** Start moving/looking as soon as the game permits it. Run `dinv status` after readiness. Expect saved inventory loaded, no prompt toggle, and eventual background probe completion. Ordinary room/chat/quest output must stay visible while wishes are checked; no wishlist, fixed report marker, or numbered fence should leak.
2. **Quiet gear control.** Run `dinv set wear psi`, then `eq` and `dinv search worn`. Confirm every intended slot, particularly the primary weapon and original portal. Require a normal completion and an idle queue afterward.
3. **Gear during navigation.** Change equipment using your usual gear command and begin familiar movement while it runs. Repeat several times with your usual spells active. Run `eq` after stopping. If Running delays a wear stage, it should resume when active, within that request's existing 30-second deadline. No weapon slot should remain empty and no false success should be printed for an incomplete set.
4. **Portal/gear overlap in both orders.** Start familiar portal navigation, then request `dinv set wear psi` while the hop runs. Repeat starting gear first, then navigation. Check the intended destination, the final requested set, and the navigation item back in its original container. A portal queued behind gear should restore the portal worn after that gear change; a gear request queued behind a hop should start after restoration. The operation may wait briefly for the preceding equipment workflow.
5. **Ordinary input around probes.** Play for at least six minutes, using normal `look`, `eq`, scans, map, spell and quest commands. Expect no resource-busy messages merely from those inputs during stats/wish/pagesize capture. One `Consumed Nx ...` summary remains per consume request; per-item consumption and cache-hit messages appear only at debug verbosity. Actual deadlines or incomplete results still produce diagnostics.
6. **Controlled cancellation.** In a safe location, start a gear change and submit `dinv cancel` separately before completion. Already-sent changes can finish; remaining queued stages must not run later. If equipment changed before cancellation, expect an interruption warning. Inspect `eq` immediately, restore the usual set, wait 30 seconds, and check `dinv status`: no stuck workflow or later old gear change. A fresh set request must complete.
7. **Reconciliation, separately.** At idle run `dinv refresh all`, then `dinv status` and check known item locations. Refresh was disabled in the reviewed sessions, so those recordings did not validate full reconciliation. Keep your original automatic-refresh preference afterward.

Stop the short test and record the time if a portal fails to restore, a slot stays empty, navigation reaches an unexpected destination, normal output disappears, or a workflow stays busy at idle. Capture `eq` and `dinv status` before manually restoring the usual set. Send the recording for review before another long session.

After these checks, monitor the same outcomes during ordinary play. Cancellation, disconnect, or a deadline may leave already-applied game changes; the correction reports this and releases ownership, rather than issuing an automatic retry or rollback.

## Before testing

1. Finish any current combat, travel or inventory operation. Quit Proteles fully, then open the newly installed `~/Applications/Proteles.app` yourself. Reloading dinv inside an already-running old app does not load a newly installed bundle.
2. Confirm recording is enabled. Keep the recording running throughout each test. Note the time at the start of each numbered test.
3. Run `dinv status`. It must show **v3.0127**. If it shows 3.0126, stop: that is the old bundle.
4. Record your normal automatic-refresh setting and period, whether your prompt is on, and which equipment snapshot/set you normally use. Choose one inexpensive movable item and one ordinary open container. Record their object IDs using `dinv search full <item name>` and `dinv search full <container name>`.
5. Run `dinv search full id <item-id>` and `dinv search worn`. Keep these as the baseline for name, location, stats and equipment. Replace `<item-id>`, `<container-id>`, and `<existing-set>` below with your real values; do not type the angle brackets.

The existing app and consistent SQLite backups are saved under `~/Documents/Proteles/Backups/dinv-3.0127-validation-20260911/`. Restoring a database would discard changes made after that backup; use the app backup alone for a code rollback unless data restoration is specifically needed.

## First session: startup, recovery and inventory

### Earlier September 11 portal/input retest (historical)

The 13:02 recording on 11 September reproduced lost restoration during two portal hops: a spell send interrupted Cowlina's Trust at 13:09:30, and `eq` interrupted Honeycomb at 13:12:25. An `eq` during equipment changes at 13:10:31 also produced a resource-busy warning and a visible fence. This correction keeps command-only bursts alive through ordinary input and checks the portal slot again immediately before entry. Full gameplay validation is pending.

1. **Restart and establish the baseline.** Finish current travel/combat, quit fully and reopen the installed app. With recording on, run `dinv status`, then `dinv set wear psi` and `eq`. Confirm the original portal and equipment are correct before testing. The version remains 3.0127; the installation record identifies this candidate.
2. **Quiet portal control.** Use familiar routes through Cowlina's Trust and Honeycomb once each. After each arrival, use `eq` and `dinv search worn`. Require the intended destination, the original portal restored, and the navigation item returned to its prior container.
3. **Input during travel.** Repeat those routes several times, using `eq` or `look` while each hop is in progress. Leave usual automatic spellcasting enabled. After every hop, check the original portal. Neither inspection nor an automatic spell should discard entry/restoration. Require no missing, repeated or delayed hop, and no visible command fence.
4. **Equipment overlap.** Use `dinv set wear psi` (or the usual alias), then submit `eq` separately while the equipment operation is running. Check all expected gear afterward. In particular, the store/wear command stages must not report `Skipping request ... resource is in use` merely because of `eq`. An interrupted stat or wish report is a separate capture outcome; note its time if it appears.
5. **Recovery check.** At idle, run `dinv refresh all` and let it complete, then `dinv status`. Require correct item locations, zero queued requests/workflows and no active request. Record test times and send the recording for review before resuming the extended session.

During the longer session, monitor original-portal restoration after travel, unexpected destinations or repeated entry, partial gear changes, visible fences, persistent busy/timeout messages, and queue/workflow counts that do not clear at idle. An occasional interrupted background capture during active play is acceptable only if a later idle refresh succeeds. If a portal fails to restore, stop travel, record `eq` and `dinv status`, and restore the normal set before further use; do not let a retry silently adopt the wrong worn portal as its baseline.

### Short retest after the Proteles timer correction

The first smoke session showed an outbound container query after reload. The correction is in Proteles's timer dispatch; dinv remains version 3.0127. **Quit Proteles completely and reopen the newly installed app before testing.** Reloading dinv alone cannot pick up this client change.

1. **Reload:** with automatic refresh off, run `dinv refresh all;dinv reload`, then `look`. After dinv reports ready, run `dinv status` and search for a known item. Run a fresh `dinv refresh all` and check status after completion. Repeat three times. Sends during the existing one-second reload delay can occur; after the old plugin disables, no old scan should issue another item command. Already-sent responses may still arrive.
2. **Cancellation after dispatch:** run `dinv refresh all` on its own. Once START appears, wait briefly (about a quarter to half a second), then submit `dinv cancel` separately, before SUCCESS. Run `dinv status`, use `look` during a 30-second wait, then check status and complete a fresh refresh. Avoid chaining refresh and cancel in one input: that only exercises cancellation before dispatch. Zero active/queued requests and workflows, retained item stats, and a successful fresh refresh are required.
3. **Automatic refresh at login:** record your original setting, run `dinv refresh on 1`, reconnect, and immediately use `look` and ordinary movement. Allow about 90 seconds including an idle period, then check `dinv status` and the known item. Require saved-data readiness, a completed synchronization, and an unchanged prompt. Restore the original setting afterward (`dinv refresh off` if it was off).

Keep recording enabled and note each test's time. Review these short results before investing in the extended session. They supplement the remaining P1–P15 coverage below.

### P1 — Immediate play during login (highest priority)

1. With your normal refresh setting, disconnect and reconnect.
2. As soon as the game accepts input, type `look`, then move one room and back on a route you know. Do this before dinv announces readiness. Continue ordinary play for the first 30 seconds.
3. Run `dinv status`, then search for the baseline item by ID.
4. Repeat three times. In one run, immediately use your usual harmless login command, such as `daily blessing`, if appropriate for your character.

Pass: each input reaches the game once; the prompt retains its prior setting; dinv loads saved inventory; searches respond; no Lua error or repeated initialization loop occurs. If automatic refresh is enabled, synchronization should eventually finish when you stop interfering with scans. A brief interrupted scan while actively playing is acceptable if a later scan succeeds.

Fail: commands disappear, repeat or execute much later; the prompt changes without your command; saved items vanish; dinv remains busy after the triggering work should have ended; or initialization repeats indefinitely.

### P2 — Startup with automatic refresh off

1. Run `dinv refresh off`, then `dinv cancel`.
2. Reconnect and immediately type `look`.
3. Run `dinv status` and search for the baseline item.
4. Run `dinv refresh all` once, then check status after its completion message.

Pass: saved inventory is available with automatic refresh off. `synchronization pending` before the manual scan is expected. The completed manual scan updates inventory without silently enabling automatic refresh. Optional wish/stat probes may still run independently.

### P3 — Complete refresh, including containers and keys

1. Stand in a safe room, outside combat, with ordinary containers open.
2. Run `dinv refresh all`. For this baseline run, allow it to finish without issuing other inventory commands.
3. Run `dinv status`, `dinv search worn`, and the baseline item's full search.
4. Compare against the game's `inventory`, `equipment`, and the contents of your chosen container. Include one keyring item if you use a keyring.

Pass: the refresh finishes successfully; workflow and queue counts return to zero; locations and worn items agree with the game; identified stats retain their expected values. A full scan takes as long as its item count requires: the 30-second deadline is per request, not for the entire inventory.

If you have never built dinv for this character, the existing build requirement still applies. Do not use `dinv build confirm` to repair an established database during these tests: build resets inventory/configuration/cache state. Record the unexpected build requirement as a failure instead.

### P4 — Inventory changes during a refresh

1. Start `dinv refresh all`.
2. While it is running, use ordinary game commands to put your test item in its container and retrieve it. Also type `look`.
3. Let the current request finish or report interruption. Check the item's actual location and its dinv search result.
4. Run `dinv refresh all` again while idle.

Pass: manual commands execute once; dinv either incorporates the observations or rejects an overlapping snapshot. The second refresh succeeds, and the item has the correct location and stats. No item disappears merely because a snapshot was interrupted.

### P5 — Explicit cancellation and reuse

1. Start `dinv refresh all`, then promptly run `dinv cancel` and `dinv status`.
2. Wait 30 seconds while using `look` normally. Check status again.
3. Run another `dinv refresh all` and allow it to finish.

Pass: after cancellation, active/queued requests and workflows return to zero; captures no longer suppress ordinary output; canceled work does not later identify or move more items. A response to an already-sent command may still arrive. The new refresh is admitted and finishes. Periodic work may start again after its configured interval.

If cancellation happened while an item was being moved for identification, verify its actual location before continuing. Cancellation cannot undo a move already sent to the game.

### P6 — Reload and reconnect during work

1. Start a full refresh and run `dinv reload` while it is active. Immediately type `look` when input is available.
2. Check `dinv status` and the baseline item after the reload. Run another full refresh.
3. Repeat, this time disconnecting during the refresh, then reconnecting and playing immediately.

Pass: saved items and stats survive; old captures do not resume or complete against the new session; no obsolete item commands run later; the next full refresh succeeds. A new session starts with synchronization pending even though saved inventory is already loaded.

### P7 — Prompt settings and unrelated output

1. With your prompt on, reload dinv and repeat the early `look` test. Verify the prompt remains on.
2. At idle, deliberately turn the prompt off using your normal game command. Reload dinv. Verify it remains off, then restore it yourself.
3. During startup and a refresh, watch room descriptions, chat and normal combat output. Also check that dinv's own wish-list/identify output does not remain gagged beyond the operation.

Pass: dinv never changes the server prompt setting; unrelated output remains readable; temporary output suppression ends after completion or cancellation. An observed prompt of `unknown` is acceptable until the GMCP reply arrives.

## Second session: existing workflows

Run these after P1–P7 pass. Use existing, familiar configuration and inexpensive items.

| Test | Procedure | Pass condition |
| --- | --- | --- |
| P8 — Get/put | `dinv put <container-id> id <item-id>`, then `dinv get id <item-id>`. Search after each step. | Exactly one intended move each time; correct final location; no permanently busy operation. |
| P9 — Equipment | Display your existing set with `dinv set display <existing-set>`, then wear it using `dinv set wear <existing-set>`. Compare `equipment` and `dinv search worn`. Restore your normal set afterward. | The expected items are worn, scores/choices remain consistent, and the operation finishes. |
| P10 — Snapshots | Create a temporary named snapshot with `dinv snapshot create dinvtest`; display it, wear it, and delete it after checking the result. | Snapshot content and worn equipment agree; existing snapshots remain intact. |
| P11 — Consumables | Check `dinv consume display`. In the normal shop, buy exactly one inexpensive configured consumable with `dinv consume buy <type> 1`. Verify the game confirms one purchase and the count/location match. | No duplicate purchase, correct counts and destination, and no delayed repeat. Do not automatically retry an ambiguous purchase: inspect inventory first. |
| P12 — Ordinary failure | Close the chosen container and try retrieving the test item through dinv. Reopen it, then repeat normally. Use only an ordinary container you can open again. | Failure is reported without a stuck workflow or corrupt item data. The subsequent valid request succeeds. |
| P13 — Character state | During a refresh, sleep or enter a short, familiar combat encounter. Return to standing outside combat and run another refresh. | Work requiring an active character stops/defers without wedging; ordinary gameplay remains responsive; the next refresh completes. |
| P14 — Portals | On a safe, familiar route, use your usual portal/travel command once, then repeat after arrival. Check held/worn equipment before and after. | One intended traversal per request, correct destination and restored equipment; no duplicate `enter` or later unexpected hop. |
| P15 — Persistence | Quit fully after successful scans, reopen, and compare the baseline item, sets, snapshots, wishes and consumable configuration. | Saved state survives the restart and loads before optional network probes complete. |

## Longer session and acceptance

Restore your original automatic-refresh setting (`dinv refresh on <minutes>`, `dinv refresh eager <minutes>`, or `dinv refresh off`). Play normally for at least one usual session, including travel, looting, purchases and equipment changes. Check `dinv status` after several idle periods. It should not accumulate queued requests or workflow counts over time.

Acceptance requires P1–P7, each applicable P8–P15 workflow, and the ordinary-play session to pass. Mark inapplicable workflows as skipped. A successful build or offline replay is not a substitute for this sign-off.

For each result, send: **test ID, pass/fail/skipped, approximate time, exact commands, expected result and observed result**. For a failure, include `dinv status` output immediately afterward and the recording filename. Leave the recording intact so the INPUT/SEND/RECV/GMCP ordering can be inspected. Capture evidence before reloading; then use `dinv cancel` if needed.

## Automated coverage and limits

The portable Lua scheduler tests cover owned deadlines, queued cancellation, cleanup once, exception recovery, cancellation generations, response boundaries and pending note input. Proteles integration tests use its actual Lua VM, compatibility shim, triggers and SQLite with a deterministic clock and simulated server output. They cover startup packet ordering, delayed prompt replies, complete/partial/stale/malformed snapshots, matching and interrupted identification, SQL rollback, parser ownership, cancellation, full refresh and reconnect persistence.

Live latency, actual server responses, host send-hook ordering, coexistence with the rest of your enabled plugins, and full equipment/portal/purchase behavior require the tests above. The compatibility simulation is not a live MUSHclient test.
