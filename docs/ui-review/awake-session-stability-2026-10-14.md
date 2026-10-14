# Awake session stability follow-up

## Incident and confirmed cause

On 2026-10-14 (Asia/Shanghai), the running app logged successful sleep-prevention activation followed by passive OFF observations: 11:17:16 → 11:57:07, 12:14:48 → 14:15:02, 14:39:46 → 16:02:33, and 17:47:21 → 17:47:50. These intervals were not a fixed timeout. No corresponding explicit OFF request or `auto_off elapsed` appears at those transitions. The helper then successfully disabled sleep prevention and released the display assertion.

The code used the live IOHID Caps Lock bit as the session's requested mode in polling, focus callbacks, presentation, and CLI status. A passive OFF lasting beyond the 350 ms debounce was enough to end the session. `secure_input_focus` names the callback that observed the state; it does not prove that secure input caused the change. Historical logs do not identify the OS component or other program that changed the keyboard state.

An installed-app fault injection reproduced this causal path on the previous build: while Keep running was active and the lid open, changing only the physical Caps Lock state made the app report logical OFF and execute `poll_debounced capslock=off helper_status=0`. There was no menu/CLI OFF command. The test restored the original keyboard state afterward.

A second code defect made intent detection unreliable: the dedicated-mode event tap swallowed Caps Lock events before the existing NSEvent monitors could observe them.

## Fix

- Add an explicit session state, initially seeded from the first available keyboard read. Subsequent polling/focus/input-source observations do not change it, including unavailable reads.
- Confirmed menu/settings/shortcut/CLI commands and auto-off results change the session. Failed HID commands retain the previous requested mode and report failure.
- Route Caps Lock key events from the dedicated filter before it strips/swallows them; retain NSEvent monitoring when the filter is disabled. Ignore events generated during/recently after the app's own HID writes and while secure-field overrides are active.
- Drive helper state, display assertions, timer evaluation, lid-lock eligibility, settings/menu presentation, and CLI logical status from the session. Continue returning the separate physical Caps Lock field. `doctor` compares requested session state with actual sleep prevention.
- Recheck session intent in queued OFF work, so a newly accepted ON request cannot be undone by a stale callback. Input-source recovery also rechecks pending explicit operations.
- Keep the existing closed-lid guard for observed external Caps Lock key events. Passive keyboard drift cannot end the session regardless of lid position. A failed keyboard resynchronization cannot cancel a running session.
- Emit a bounded `keyboard_state_drift ... action=preserve_session` diagnostic when keyboard and session state disagree.

The session remains in memory; startup still adopts keyboard state, as before. This change does not add persistence across application restarts. Keyboard control is temporarily ignored during programmatic HID writes and their 500 ms event-settling window; UI/CLI commands remain explicit controls.

## Verification

- Installed previous build: the new opt-in running-app test fails on the first injected OFF, reproducing the session-cancellation path; original physical state restored.
- Full suite: 184 tests, 3 opt-in tests skipped, 0 failures.
- Regression coverage includes repeated OFF/unavailable observations after two hours of simulated elapsed time without cancelling the session or resetting its three-hour timer, explicit/auto-off commands, failed commands, physical-key control, secure-field state changes, and delivery from the swallowing event filter.
- Release app/helper signed with the existing Apple Development identity, team B829A49G4D. The local installer package is unsigned, not notarized.
- Installed at 18:47 Asia/Shanghai after administrator authentication. Installed app and privileged helper exactly match the signed package payload; strict signatures pass. Installed app executable SHA-256: `c8a8150e41ec1d9f21fd6997137c0661f724b24b3d81c6ab059489a386ab0b9a`.
- The same opt-in installed-app fault injection now passes: 5 rounds of physical OFF/restore, with 12 status samples at 250 ms intervals per round (60 observations), 0 failures. Requested awake mode and actual sleep prevention remained on. Total test duration: 23.731 seconds. Original physical state restored. Command: `CAPSOMNIA_SESSION_HARDWARE_TEST=1 swift test --filter RunningAppSessionTests` under the full Xcode toolchain.
- Logs confirm `keyboard_state_drift physical=off requested=on action=preserve_session` during injected drift, with no matching helper OFF. A drift observed at 18:47:55, before this injection test, was also retained.
- Native UI verification: an automated Caps Lock key event reached the key handler and successfully disabled sleep prevention; settings then reenabled it. This verifies the event path, not a human pressing the physical keyboard.
- Installed settings UI: 10 complete off/on rounds, 20 transitions, all confirmed. A normal stopping phase was allowed to settle before checking OFF; no failed transition occurred. Final doctor reports healthy, logical and physical Caps Lock on, sleep prevention enabled, and no timer. Computer Use and lid-open lock settings were preserved.
- No source behavior changed after building/installing; the later source edit only clarifies a comment.

Simulated elapsed-time tests are not a two-hour wall-clock soak. The fix removes the reproduced application-level coupling; it does not establish which external component produced every historical keyboard-state change.
