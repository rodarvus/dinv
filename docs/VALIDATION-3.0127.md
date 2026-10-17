# dinv 3.0127-3.0130 validation record

Live status: on October 17, 2026, the user reported that the focused Proteles tests for 3.0130 passed and authorized committing and pushing the accumulated DInv changes. An extended session is still pending. MUSHclient live validation remains separate. The September records below describe earlier candidates and checks.

## October 17: focused Proteles acceptance of 3.0130

The focused plan covered portal admission during Running, identification during ordinary input, missing/moved-item refresh handling, analysis beyond the old one-minute limit, consumption counts at standard verbosity, and cancellation followed by a fresh refresh. Acceptance is based on the user's report; a new recording review was not performed for this commit.

Final portable checks:

| Check | Result |
| --- | --- |
| `clua tests/runtime_spec.lua` | 102 assertions passed. |
| `clua tests/portal_cli_spec.lua` | 196 assertions passed. |
| `clua tests/operation_regressions_spec.lua` | 74 assertions passed. |
| `clua tests/identification_input_spec.lua` | 298 assertions passed. |
| Syntax and metadata | 29 Lua files passed syntax checks; XML parses, loaded modules are present in the manifest, and version metadata agrees on 3.0130. |

No Proteles files, build, installation, release or tag are part of this commit operation. The runtime source, portable tests and coordination documentation are committed together; the host-specific historical checks below were not rerun here.

## September 16: complete workflows and report noise

The September 15–16 review covered nine recordings, ending at 08:29:30 BST on September 16 (first 634,054 lines of that day's main recording). In `session-20260915-065210.log`, the gear operation at 11:08:29 removed/stowed the primary weapon; Running at 11:08:30 canceled the remaining wear stage. Slot 24 was not filled until another gear request at 11:40:33. At 09:30:41 a gear stage stowed the portal hop's original item between hold and restoration; the restoration then received missing-item responses.

The review found 68 ungagged markers (57 coordinator prefixes, 11 fixed stats markers), 80 probe-busy notes, and 17 wish deferrals in combat. Of 1,757 dinv notes, 1,600 were consumption/cache detail; 380 cache notes had an empty name. These are counts from the pinned reviewed window, not the growing recording. Automatic full refresh was disabled; these sessions do not validate reconciliation.

The candidate reserves complete gear/portal workflows, waits through Running within existing deadlines, verifies final equipment, preserves canceled marker gags, narrows/stages reports, removes fixed report echoes, checks wish admission before pagesize, and quiets routine details. Proteles's old 80-line host wishlist gag is removed with the bundle update; it depended on the fixed marker and would otherwise hide unrelated lines after it disappeared.

Before correction, real Lua/shim regressions failed for the missing replacement weapon, canceled-prefix leak and pagesize probe during combat. The full-session wishlist tests additionally failed while the host-wide gag remained: normal output was swallowed. With the corresponding source changes, the focused tests pass, including portal/gear order in both directions, restoration rejection, Running resume/cancel/timeout, partial report retention and colored wish rows with a competing trigger.

| Check | September 16 result |
| --- | --- |
| Portable coordinator | `clua tests/runtime_spec.lua`: 102 assertions passed. |
| Lua/distribution | All 24 modules and generated single-file Lua syntax-check; XML parses; all 23 loaded modules are in the 3.0127 manifest. |
| Proteles macOS | `swift build` passed; `swift test --parallel`: 2,140 tests in 429 suites passed (1,967 MudCore, 103 MudUI, 70 output-view). A subsequently added rejected-wear regression passed with the four-test `DinvWorkflowTests` focused run. |
| Formatting/lint | Repository-wide `swiftformat --lint .`: 0/785 files need formatting. `swiftlint --strict`: zero violations. The formatter failure recorded for September 11 no longer occurs in the current checkout. |
| Vendoring | Development-source `scripts/vendor-plugins.sh --check` passed with the normal remaining Proteles patch. |
| iOS | `xcodebuild test -scheme MudCore-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`: 1,968 tests in 392 suites passed; `TEST SUCCEEDED`. |
| Release/install/live | Not performed; the user will build the app and validate gameplay. |

 The first iOS run completed with one failure in the existing `DinvQueuePatternTests` ten-second wall-clock assertion while another test build was running. Its simulated wire had reached the second fence but not `QUEUE_DONE`. Xcode then stalled finalizing that failed run's log and was stopped after test results were printed. The complete simulator rerun, with no competing build, passed without changing production behavior or that test's timeout. This is consistent with the same timing-sensitive failure recorded on September 11; it is not evidence of a connected-session fault.

Follow the September 16 section of [the live test plan](PROTELES-TEST-PLAN-3.0127.md) after building your app. Simulator and simulated-wire checks do not establish connected gameplay behavior.

## Extended-session follow-up: portal and equipment interruption

Evidence: `session-20260911-130206.log`, 11 September 2026, BST. Its header identifies Proteles 0.8.8 (56), Release, `b802401c dirty`, from the installed timer-correction build.

The reload at 13:08:12.542 halted the old scan without another old container query afterward. At 13:08:18, status showed saved inventory loaded, no active request and zero queued requests/workflows; a fresh scan completed at 13:08:27.132. A separate cancellation at 13:08:39.758 interrupted a dispatched scan; the next scan completed at 13:08:52.974. Automatic refresh was enabled at 13:08:57.616. These observations support the timer correction, but a new login with automatic refresh enabled was not captured in this retest.

The subsequent travel exposed a separate cancellation regression:

| Recorded time | Observed sequence |
| --- | --- |
| 13:09:29–31 | Cowlina's Trust was equipped. An automatic `cast 'energy shield'` at 13:09:30.450 arrived after the finish prefix reply but before deferred dispatch. Entry/restoration were discarded. The navigation retry entered with no restoration commands, adopting the navigation portal as its original equipment. |
| 13:10:31 | During the gear command, `eq` at 13:10:31.629 canceled the store-old-set command burst. The resource-in-use warning followed at .641. Fence 177 returned at .718 without a GAG record because its trigger had been removed. The later wear stage did restore the original portal. |
| 13:12:25–27 | Honeycomb's remove/get/hold commands were sent at 13:12:25.389–.390. `eq` at .568 canceled the hold request while its suffix was pending. The server still equipped Honeycomb. A later retry sent `enter` without wear/put, leaving Honeycomb equipped. Earlier Honeycomb hops at 13:10:53 and 13:11:04 had restored correctly. |

Cause: the coordinator classified every non-framed request as a text capture, including parser-free equipment and portal command bursts. Foreign sends canceled those bursts and their remaining restoration callbacks. The game did not reject missing restoration commands; dinv never sent them.

The correction distinguishes output capture from command acknowledgement using the presence of a response setup callback. Pure command bursts retain their fences and continue through ordinary input. Actual unstructured captures still reject foreign input, and framed snapshots still reject competing raw requests. A protected pre-dispatch check revalidates the portal slot after the finish prefix. It skips entry and replacement if the slot changed, while retaining restoration for a failed hold into an empty slot. Explicit cancel, lifecycle invalidation and deadlines still stop work. No automatic retry or general game-side rollback was introduced.

The new `DinvPortalInterferenceTests` reproduced the recorded hold, finish and equipment interruption failures before the change; the uninterrupted control and explicit-cancellation control passed. A separate stale-slot test also failed before the guard. With the correction, all five tests pass, including both slot-change timings, failed-hold restoration and suppression of the pending equipment fence after `eq`. The slot-change guard is precautionary coverage; the two recorded portal failures were missing restoration, not entry through the wrong portal.

Validation results:

| Check | Result |
| --- | --- |
| Portable Lua | `clua tests/runtime_spec.lua`: 75 assertions passed, including capture classification and rejected/throwing dispatch preconditions. |
| Syntax and distribution | All 24 Lua modules, generated single-file script and XML passed; module manifest coverage and version 3.0127 match. |
| Focused integration | 21 tests in 4 suites passed: coordinator, portal interference, real-session lifecycle, and the existing queue-pattern test. |
| macOS suite | Final `swift test --parallel`: 2,130 tests in 427 suites passed. |
| iOS suite | 1,957 tests in 390 suites passed. |
| Build and lint | `swift build`, strict SwiftLint and the Release build passed. The new Swift test file passes SwiftFormat; the existing repository-wide 280-file formatting mismatch remains. |
| Bundle | All 29 Release dinv resources match the tested vendored sources; the development vendor check and strict/deep signature verification pass. |

The first parallel macOS run passed the new regressions but exceeded the existing queue-pattern test's ten-second deadline while other builds ran concurrently. That test passed on the focused rerun and the complete macOS rerun passed. No production or test timing code was changed to obtain the rerun result.

The signed Release candidate was installed at **13:31 BST on 11 September** to `~/Applications/Proteles.app`, still Proteles 0.8.8 (56) with dinv 3.0127. All 29 installed dinv resources match the tested sources and the installed binary matches the Release build. Four dinv resources differ from the timer-correction app: `dinv_commands.lua`, `dinv_dbot.lua`, `dinv_portal.lua` and `dinv.changelog`. The preceding timer correction remains included. `PORTAL-CORRECTION-INSTALL.json` records all hashes, and `Proteles-before-portal-correction.app` preserves the prior app in the existing validation backup directory. The app was not launched and no database was modified by installation.

Live verification of this portal correction is pending. Follow the portal/input short retest in the test plan before a longer session. Actual report captures can still be interrupted during active play; persistent failure to recover at idle remains a failure. Retained command bursts also mean input that intentionally changes equipment needs particular care: the portal guard observes invmon state at dispatch, but already-sent commands cannot be recalled.

## Smoke-test follow-up: timer ordering

The first smoke session accepted early input, retained the prompt setting and completed five full refreshes. The snapshot ID sets were 406, 406, 405, 405 and 405 items; the only removal was the item sold during the session. Explicit cancellation was tested before dispatch, and automatic refresh was off.

During reload, the old scan reported halted and disabled at 12:36:04.387 BST; a container query was sent at 12:36:04.656 after the new instance reported ready. A session regression reproduced this with the real bundled dinv: Proteles collected all due timer callbacks' effects before applying the earlier reload effect.

The correction changes Proteles's timer dispatch to snapshot due IDs, recheck each timer's current state and apply its effects before running the next callback. It preserves the timer ordering, recurring-timer coalescing and next-tick scheduling rules. The dinv Lua bundle is unchanged from the smoke build.

Before the correction, both new session regressions failed with obsolete sends reaching the simulated connection (including dinv's container query). With the correction, the expanded tests also cover cancellation during a partial snapshot, ignoring its late end marker, preserving saved item data, completing a fresh snapshot and delivering unrelated sends once.

Correction checks:

| Check | Result |
| --- | --- |
| Regression before correction | Both original session regressions failed with obsolete sends on the simulated connection. |
| Focused timer, lifecycle and dinv suites | 72 tests in 14 suites passed. |
| Final lifecycle/state assertions | 16 focused tests passed on both macOS and iOS, including both reload and cancel cases. |
| macOS suite | `swift test --parallel`: 2,125 tests in 426 suites passed. |
| iOS suite | `xcodebuild test -scheme MudCore-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`: 1,952 tests in 389 suites passed. |
| Build and lint | `swift build` and repository-wide `swiftlint --strict` passed. All six Swift files changed for this correction passed SwiftFormat. |
| Repository-wide formatting | Still fails on 280 files with the installed formatter; the pre-existing formatter mismatch described below remains. |
| Release and install | Signed Release build succeeded; installed at 12:58 BST on 11 September. Strict/deep signature verification passed. The installed binary contains the new timer-dispatch symbols and matches the built binary hash. |
| Bundle | All 29 dinv resources match both the tested checkout and the preceding smoke-test app byte-for-byte. The development vendor check passes. |

Proteles remains 0.8.8 (56), with dinv 3.0127. The correction is identified by the installation record `TIMER-CORRECTION-INSTALL.json` in the existing validation backup directory. That directory also contains `Proteles-before-timer-correction.app`. The installed binary SHA-256 is `c1d58ce5af72b62042b67b288d602799fb5d437d3d8a666df7104037b67b8a6d`.

At installation, live verification of the timer correction was pending. The later recorded reload and cancellation observations are listed above. Timer callback ordering affects all generic plugin timers; the lifecycle tests explicitly retain unrelated sends, while the full suites cover existing timer behavior. The original build's checks below remain a separate record.

## Completed checks

| Check | Result |
| --- | --- |
| Portable Lua scheduler | 33 assertions passed with `clua tests/runtime_spec.lua`. |
| Lua 5.1 syntax | All 24 Lua modules passed; the generated single-file script also passed `cluac -p`. |
| Distribution | Single-file XML generated and parsed; every loaded module is included in the manifest. |
| Proteles coordinator regressions | 13 tests passed using the real Lua VM, shim, triggers and SQLite with simulated clock/wire input. |
| All dinv-focused Proteles tests | 31 passed. |
| Full Proteles test suite on final changes | 2,122 tests in 425 suites passed. |
| Swift package build | Passed. |
| SwiftLint | Repository-wide strict check passed with no violations. |
| SwiftFormat, changed Swift files | Passed for all four changed/new Swift files. |
| Release build | Generated macOS project/scheme built successfully and passed strict code-signature verification. |
| Installation | Installed to `~/Applications/Proteles.app`; all 29 bundled dinv files matched the tested vendored resources byte-for-byte. The app was not launched. |
| Working-tree vendor check | `DINV_SOURCE_DIR=/path/to/dinv scripts/vendor-plugins.sh --check` passed. |

## Existing formatting gate failure

Repository-wide `swiftformat --lint .` with installed SwiftFormat 0.63.0 reports 283 files requiring formatting. Running the same formatter on a clean archive of Proteles HEAD reports 284. The changed Swift files pass; unrelated formatting was left untouched. Therefore the repository-wide four-gate requirement is **not fully green** and still needs attention before a later commit.

## Integration and rollback

Proteles's submodule pin remains at dinv 3.0126 (`ee45156`) until live acceptance permits committing 3.0127. The development source override supplies the uncommitted checkout to both vendoring and its comparison check. The ordinary pinned-source check is not expected to match this development bundle yet.

Original-app copies, four consistent SQLite backups, a backup manifest and the installed dinv file hashes are under `~/Documents/Proteles/Backups/dinv-3.0127-validation-20260911/`. Database backups were made with SQLite's backup API and passed `PRAGMA quick_check`.

Follow [the ordered Proteles test plan](PROTELES-TEST-PLAN-3.0127.md), starting with P1–P7. Builds, simulated responses and signature checks do not prove behavior in a connected game session. MUSHclient live validation remains separate.
