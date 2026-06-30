---
title: >-
    Kori iOS build & run gotchas (Debug dev-client crash, Release workaround, sim automation)
category: concepts
tags: [kori, ios, expo, expo-dev-launcher, xcode, simulator, type/howto]
sources: [projects/kori]
summary: >-
    Kori's Debug dev-client build crashes at launch ("Cannot find the keyWindow") because AppDelegate was migrated to the UIScene lifecycle but expo-dev-launcher still looks for keyWindow in didFinishLaunching. Build Release to run it. Plus DerivedData-cache and simulator-automation gotchas.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.64
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T01:35:15Z
updated: 2026-06-30T01:35:15Z
---

# Kori iOS build & run gotchas

Building and running [[kori]] on an iOS simulator hits several non-obvious walls. The JS side is fine; the friction is all native/tooling.

## Debug dev-client crashes at launch — build Release instead

The **Debug** build (the dev client) hard-crashes immediately at launch with:

```
EXDevLauncher/ExpoDevLauncherAppDelegateSubscriber.swift:8:
Fatal error: Cannot find the keyWindow. Make sure to call `window.makeKeyAndVisible()`.
```

Root cause: the local `ios/Kori/AppDelegate.swift` was migrated to the **UIScene lifecycle** (the window is now created in a `SceneDelegate`, not in `AppDelegate`) so the app survives iOS 26+. But `expo-dev-launcher`'s `AppDelegateSubscriber` still looks for a `keyWindow` during `didFinishLaunching` — **before** the scene has created the window — so it fatal-errors. The JS bundle loads fine (Metro reports thousands of modules initialized); the crash is purely native. ^[extracted]

Key facts:
- `expo-dev-launcher` only activates in **Debug**. ^[extracted]
- A **Release** build embeds the JS bundle and skips the dev launcher entirely, so it launches cleanly. **To actually run Kori on a sim, build Release.** ^[extracted]
- This crash is **pre-existing and independent of app/JS changes** — don't assume your edit caused it. ^[inferred]

## Release build: clean DerivedData on cache mismatch

A Release build can fail with a **stale precompiled-module (PCM) mismatch** — e.g. a Debug-precompiled `RCTDeprecation` PCM picked up by the Release build — sometimes alongside a transient "Xcode build system has crashed." This is a known gotcha in this repo; the fix is to **clean DerivedData** and rebuild. ^[extracted]

Caveat learned the hard way: **deleting cache files mid-build corrupts the build DB** ("disk I/O error"). Don't surgically delete subfolders while a build is in flight — stop the build, wipe the *whole* DerivedData for the workspace, then do **one** clean build. ^[inferred]

## Simulator UI automation may be unavailable

On a machine with a **partial Xcode-beta install**, simulator UI automation can be fully blocked even though builds and screenshots work:
- `xcodebuildmcp`'s `tap` / `snapshot_ui` rely on an accessibility bridge that needs `SimulatorKit.framework`; if the Xcode-beta is missing that framework, semantic taps and AX snapshots fail. ^[extracted]
- computer-use clicking needs `Simulator.app` GUI (`Contents/Developer/Applications`), which may not be installed. ^[extracted]
- `idb` may not be installed; `xcrun simctl` has no tap/input subcommand. ^[extracted]

Net effect: you can *screenshot* the simulator but not *tap* it, so you can confirm the app launches but cannot drive onboarding end-to-end from the agent. Reaching late onboarding steps is also gated by a paywall and a `speakFirst` step that needs real mic/speech (a simulator can't provide it). ^[extracted]

Related: [[kori]], [[kori-navigation-architecture]], [[ios-permission-review-prompts]].
