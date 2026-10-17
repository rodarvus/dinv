# Operation coordination

The game remains asynchronous. Version 3.0127 replaces the polling queue and unowned `wait.make`/`wait.time` continuations with a small coordinator. It does not rewrite equipment selection, scoring, item storage or every sequential domain workflow.

- `dinv_runtime.lua` owns timers and supervised continuations. It resumes a waiting caller once, after the current trigger dispatch, and drops continuations from an invalidated generation. Existing long workflows retain coroutines behind this adapter; the external `wait` framework is no longer required. The separate HTTP updater still uses `async` on MUSHclient and remains unavailable in Proteles.
- `dinv_commands.lua` serializes dinv's game requests. A request owns its command list, response setup/cleanup, result, caller, creation time and deadline. Queue residence counts against the caller's timeout. An expired queued request never dispatches. User game commands are not buffered by dinv.
- `dinv_capture.lua` stages framed inventory responses and full identification text. Publication requires the matching end marker, a valid identity/row shape, and no conflicting inventory revision. Item and cache changes are published under a SQLite transaction. A failed transaction restores the in-memory candidate state.

## Startup and observation

Readiness means a fresh `char.base` packet supplied a nonempty character name and saved data loaded successfully. Either ordering of `char.base` and `char.status` is supported. A cached or empty GMCP table is insufficient. Inventory synchronization is separately reported and respects existing build/automatic-refresh preferences.

Prompt state is observed as unknown/on/off. A late reply updates the observation. No startup or request changes the server's prompt setting. Inventory changes observed during startup are buffered with a fixed bound; initial reconciliation supplies the authoritative complete view.

## Response boundaries and cancellation

`invdata`, `eqdata`, and keyring snapshots finish on their matching protocol tags. A changed inventory revision rejects an overlapping snapshot. Unstructured reports and legacy command bursts still require unique echo boundaries. There is no server request ID, so local operation IDs cannot distinguish arbitrary interleaved identical reports. Conflicting user input cancels capture; a subsequent boundary drains older traffic before another parser starts.

Requests with a response setup callback capture output. Generic legacy captures are interrupted by foreign sends; framed snapshots reject competing raw snapshot requests. Stats, wishes and pagesize use narrow report patterns and explicit conflicting verbs (including their abbreviations), so ordinary movement, map, scan, spell and quest sends do not invalidate them. Recognized complete stats/wish data survives unrelated input while the unique completion fence is pending. Reports stage their results until successful completion; missing or canceled captures retain saved values. Pagesize changes still invalidate a pending pagesize query, even after its first response line, so an old value cannot overwrite a newer user choice. Command bursts without response setup only await their unique acknowledgement, so ordinary input and automatic spells do not cancel their remaining equipment or portal steps. Explicit cancellation, deadlines and lifecycle invalidation still apply to both kinds of request.

Identification uses its existing echo boundaries instead of canceling on every foreign send. Input received before dispatch requires a fresh opening fence, including input between the opening reply and the scheduled dispatch. Once the identification burst and closing fence are sent, later commands follow that fence and do not cancel capture. Replacing an opening fence never extends the original deadline. Identity validation, state admission and explicit cancellation remain in force.

The scheduler releases parser resources before delivering completion. A queued request has not acquired a parser, so its timeout must not disable the active request's triggers. Explicit cancel, disable, disconnect and teardown invalidate existing continuations. An unexpected workflow exception aborts the generation and restores admission rather than preserving partly owned locks.

The client must apply each due timer's effects before running the next timer callback, rechecking whether that timer still exists and is due. Otherwise it can collect a reload and an old continuation's send in one batch, then send the obsolete command after loading the new plugin instance. Proteles's timer dispatch follows this ordering; the Lua coordinator alone cannot retract an outbound effect the host has already collected. Newly scheduled timers wait for the next tick, while unrelated due timers retain their scheduled order.

Cancellation is not a transaction on the game. Already-sent commands may still execute. Existing mutation workflows keep their inventory/location checks. Portal entry requires successful hold completion and another slot check after the finish request's opening fence, immediately before dispatch. If another item has replaced the navigation portal, the request skips entry and leaves that equipment choice alone. A failed hold can still restore an empty slot. No generic automatic retry is added for purchases, equipment changes or portal travel; reconcile observed game state before repeating an ambiguous mutation.

## Equipment workflow ownership

Equipment-set application and portal travel acquire a FIFO reservation before inspecting equipment and building mutation commands. While reserved, only that owned task's requests dispatch. The reservation covers gaps between batches; user sends and immediate consumables retain their existing paths. A portal queued after gear observes the completed gear as its restoration baseline. Duplicate portal requests remain coalesced while their task is alive.

Acquisition has a 30-second deadline. Individual gear requests retain their 30-second deadlines, with a 90-second total reservation limit; a portal has a 15-second reservation limit after acquisition. A temporary Running state delays unsent equipment work without restarting deadlines. Already-sent bursts retain their acknowledgement. Active/combat state resumes waiting work behind a fresh boundary. Explicit cancellation and expiry release ownership and suppress later continuations. Cleanup also restores the refresh state and temporary wear suppression after an error.

The final fence proves command ordering, not server acceptance. Set application verifies every requested item location before reporting success; portals verify the original slot and navigation-item container. A rejected restoration or interrupted partial mutation is reported for manual inspection. Game-side rollback is not attempted.

Outstanding canceled markers retain exact one-shot gag triggers, independent of parser and caller ownership. They cannot dispatch or resume work. At most 64 canceled markers are retained; the oldest is evicted beyond that bound. Plugin unload removes its triggers, so suppression is not promised across a complete unload/reload. Fixed wish/stat echoes are removed; the coordinator's unique marker is the only completion fence. Empty equipment batches send no fences.

Background wishes check admission before querying pagesize. Background stats retry quietly after 30 seconds when the queue or character is busy; wish retries retain their one-minute period. Ordinary consumption retains one completion summary; cache identification and per-item consumption details use debug output with a nonempty name fallback.

Proteles removes its former host-wide wishlist gag together with this bundle update. The Lua parser owns report suppression, including startup, instead of hiding the next 80 lines in anticipation of a fixed marker. Real-session tests cover colored rows, a competing stop-on-match trigger, a missing header and interleaved unrelated output.

## Verification

Run `clua tests/runtime_spec.lua` from this repository. The Proteles integration suites are `DinvCoordinatorTests`, `DinvPortalInterferenceTests`, `DinvWorkflowTests`, `DinvReportOwnershipTests`, `DinvWishGagTests`, `WishProbeHostGagTests` and `SessionTimerLifecycleTests` in the companion client repository. They cover recorded portal/input overlaps, slot changes, command-fence suppression, and the actual session timer/send path through unload, reload and cancellation, including unfinished snapshots and fresh requests afterward. These checks use simulated connections; the live acceptance procedure is [the Proteles test plan](PROTELES-TEST-PLAN-3.0127.md).

Run `clua tests/identification_input_spec.lua` for the identification/input regression checks. These exercise the real send hook, parser and coordinator with simulated host calls, ordered responses and persistence: input before dispatch, the opening-fence scheduling gap, input after dispatch, unchanged deadlines, identity rejection, cancellation and state guards. They do not establish live client behavior.

For an uncommitted integration build, Proteles's vendor script accepts `DINV_SOURCE_DIR` pointing to this checkout. Both regeneration and `--check` apply the normal Proteles patch. The normal pinned-submodule check remains the release gate; move the submodule pin only after the dinv change is accepted and committed. This development override is not a substitute for pinning the released source.
