# Caps Lock write reconciliation follow-up

## Report and evidence

The fork user reported that enabling Keep running sometimes turned the indicator red, with a subsequent click or key action eventually making it green. Application logs at 17:47:02 and 17:47:14 Asia/Shanghai show requests to enable followed by `failed=verification actual=off`; at 17:47:39 polling observed on and the privileged helper successfully applied sleep prevention. This was a failed state transition, not just delayed painting. The user confirmed intervening input.

Those historical logs contain no per-keyboard cache snapshots. They prove the failed global-state readback but cannot conclusively identify which OS component caused it. Do not describe the original incidents as uniquely proven to have the cause below.

## Recoverable failure mechanism

Apple's published implementation writes per-keyboard `HIDCapsLockState` properties, whereas its getter reads IOHIDSystem global event flags. The keyboard filter ignores a write equal to its cached value. When these layers disagree, repeating only the requested value need not establish a new transition. The setter also does not propagate each service's property-write result, so a successful return code alone is not sufficient.

Pinned primary sources inspected on 2026-10-13:

- [IOKitUser setter and getter](https://github.com/apple-oss-distributions/IOKitUser/blob/323ead896d04424f87184d8f6ff0cce811aab106/hidsystem.subproj/IOHIDLib.c#L549)
- [Keyboard filter cache check](https://github.com/apple-oss-distributions/IOHIDFamily/blob/777ccd9698845aadf711e32d843c8c9b777431d9/IOHIDEventSystemPlugIns/IOHIDKeyboardFilter.mm#L2695)
- [IOHIDSystem global-state getter](https://github.com/apple-oss-distributions/IOHIDFamily/blob/777ccd9698845aadf711e32d843c8c9b777431d9/IOHIDSystem/IOHIDSystem.cpp#L3347)

Published Apple source explains the modeled mechanism; it does not establish that every detail matches the installed macOS build.

## Change

`CapsLockStateWriter` retains the existing three-consecutive-read confirmation and adds one bounded reconciliation for a known mismatch:

1. Write the requested state and verify it.
2. If it fails, recheck for delayed success before changing anything else.
3. Only if a known opposite state persists, synchronize keyboard caches to the state the system actually reports and verify that baseline.
4. Write the requested state again and require normal stable confirmation.

Unavailable reads, unstable matches, write errors, and an unconfirmed baseline do not trigger speculative toggling. Persistent mismatch remains failure after one reconciliation. Healthy writes use the original fast path. This is shared by the menu, settings, shortcut, CLI, and other existing controller callers. The explicit request stays pending until this operation completes; no optimistic green state is introduced. Recovery emits `capslock_reconcile` in the system log.

## Verification

- The deterministic cache/global divergence test fails with the previous one-write behavior in both directions; it passes with reconciliation enabled.
- Nine regression tests cover recovery, normal/already-matching writes, unavailable reads, persistent mismatch, errors at all three write stages, delayed success, read loss, unstable target observations, and an unconfirmed baseline.
- Full suite: 176 tests, 2 opt-in hardware tests skipped, 0 failures.
- Separately enabled hardware round-trip test: 20 cycles / 40 real state changes, 0 failures, initial state restored. Run with `CAPSOMNIA_HARDWARE_TEST=1 CAPSOMNIA_HARDWARE_CYCLES=20 swift test --filter CapsLockControlTests/testSystemSetRoundTripWhenHardwareTestIsEnabled` under the full Xcode toolchain.
- Built app and privileged helper signed using the existing Apple Development identity, team `B829A49G4D`; strict payload signature checks passed. The outer local package is unsigned, not notarized.
- Installed successfully at 19:07 Asia/Shanghai after system administrator authentication. The running application restarted from `/Applications/Capsomnia.app`; installed app/helper binaries match the verified payload and both strict signature checks passed. App executable SHA-256: `ed5edf9f3998674da312f4c67344cd78ee1906fdd7a35731d9fc31fabcb2f50b`.
- Installed settings-page smoke test: off at 19:08:38, confirmed sleep prevention released at 19:08:39; on at 19:08:54 with successful HID confirmation, helper application, and display assertion. The native UI showed off/on consistently and the local `doctor` endpoint reported healthy. This check did not exercise the mismatch recovery branch.
- Manual reproduction through the original menu-bar path has been requested from the reporter. Native automation verified the settings window but could not expose the menu-bar item; do not label the settings-page smoke test as a manual menu-bar test.

The historical intermittent event was not reproduced on demand during these tests. The deterministic regression verifies the recoverable mismatch path, while hardware cycles verify ordinary transitions. Neither is evidence that all possible OS/keyboard interference has been eliminated.
