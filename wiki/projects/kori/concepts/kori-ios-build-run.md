---
title: >-
    Kori iOS build & run gotchas (device install, scene-lifecycle crash, Debug dev-client crash, sim automation)
category: concepts
tags: [kori, ios, expo, expo-dev-launcher, xcode, simulator, devicectl, uiscene, codesign, type/howto]
sources: [projects/kori]
summary: >-
    How to build & install Kori on a physical iPhone when Xcode-beta has no Simulator (xcodebuild Release + devicectl), the iOS 26+ scene-lifecycle SIGTRAP and its SceneDelegate fix, the iCloud-derivedDataPath codesign trap, plus the Debug dev-client keyWindow crash and sim-automation walls.
provenance:
  extracted: 0.62
  inferred: 0.3
  ambiguous: 0.08
base_confidence: 0.64
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T01:35:15Z
updated: 2026-06-30T04:22:30Z
---

# Kori iOS build & run gotchas

Building and running [[kori]] on iOS (simulator *and* physical device) hits several non-obvious walls. The JS side is fine; the friction is all native/tooling.

## Installing on a physical iPhone when the Simulator is missing

This Mac has **only Xcode-beta (27.0 / iOS 27 SDK), and `Simulator.app` + all sim runtimes are absent** from it. Consequence: `npx expo run:ios --device <udid>` aborts on a preflight — Expo opens the Simulator even for device targets (`Can't determine id of Simulator app`). ^[extracted]

Route around Expo entirely and build the device directly in **Release** (standalone — JS bundled in, no Metro needed on the QA phone): ^[extracted]

```
cd ios && LANG=en_US.UTF-8 xcodebuild -workspace Kori.xcworkspace -scheme Kori \
  -configuration Release -destination 'id=<ECID-udid>' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/KoriCLI" \
  -allowProvisioningUpdates build
# then:
xcrun devicectl device install app  --device <CoreDevice-uuid> "<…>/Release-iphoneos/Kori.app"
xcrun devicectl device process launch --terminate-existing --device <CoreDevice-uuid> com.kori.learnkorean
```

- **Two different device IDs.** `-destination id=` wants the **ECID UDID** (from `xcrun xctrace list devices`); `devicectl` wants the **CoreDevice UUID** (from `xcrun devicectl list devices`). They are not interchangeable. For VC iPhone 17 Pro: ECID `00008150-001408410CB8401C`, CoreDevice `E2DC6CBB-5E55-51B1-A9DF-D49A7DE72F64`. ^[extracted]
- Signing already works: **Automatic, team `9SKC52K3ND`**; provisioning resolves for the app **and both extensions** (LiveActivity, KoriWordWidget). ^[extracted]
- If `process launch` returns `FBSOpenApplicationServiceError … Locked`, **the install succeeded** — the phone just needs unlocking. Retry the launch or tap the icon. ^[extracted]
- No device screenshots here: `idevicescreenshot` needs the Developer disk image mounted (not available via libimobiledevice on this box). Verify "it didn't crash" via process state (`devicectl device info processes`) + absence of fresh crash reports instead. Pull crash reports with `idevicecrashreport -u <ecid> -k <dir>`. ^[extracted]

## iOS 26+ SDK scene-lifecycle SIGTRAP at launch

The first device install **launched and instantly closed**. The crash report showed `EXC_BREAKPOINT`/`SIGTRAP` in `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption` — the **iOS 26+ SDK UIScene-enforcement crash**. Kori's `Info.plist` declared a bare `UIApplicationSceneManifest` (only `UIApplicationSupportsMultipleScenes=false`) while the stock Expo SDK 54 / RN 0.81 `AppDelegate.swift` still used the **legacy window lifecycle with no SceneDelegate**. Built against the iOS 27 SDK, UIKit hard-crashes that mismatch. ^[extracted]

**Fix applied this session** (committed): added `UISceneConfigurations` → `$(PRODUCT_MODULE_NAME).SceneDelegate` to both `ios/Kori/Info.plist` and `app.json` (so `expo prebuild` won't reintroduce it), moved window creation + `factory.startReactNative(withModuleName:"main",in:window,…)` out of `didFinishLaunching` into a new `SceneDelegate` class (kept inside `AppDelegate.swift` to avoid `project.pbxproj` edits), and added `configurationForConnecting`. After the fix the process stays up past the scene-connection point where it previously died in ~1s. See the general writeup: [[ios26-scene-lifecycle-launch-crash]]. ^[extracted]

> ⚠️ **Discrepancy to recheck.** The earlier (simulator) note below says the AppDelegate "was migrated to the UIScene lifecycle" already. This device session read `AppDelegate.swift` and found it **stock-legacy with no SceneDelegate**, then added one. The two observations conflict — re-read the committed `AppDelegate.swift` to know the current truth; the device-session finding is source-verified and more recent. ^[ambiguous]

## Build OUTSIDE the iCloud-synced repo, and watch NODE_BINARY

- The repo lives in `~/Documents/Stratton/kori`, and **Documents is iCloud-Drive synced**, which makes `codesign` reject the `.appex` extensions ("resource fork, Finder information … not allowed"). Always use a `-derivedDataPath` under `~/Library` (e.g. `…/DerivedData/KoriCLI`), **not** `./build`. Full explanation: [[icloud-synced-repo-breaks-codesign]]. Switching the derivedDataPath then needs a `pod install` to regenerate RN codegen (`ios/build/generated/...`). ^[extracted]
- **Hermes "Replace Hermes" script phase** fails (`PhaseScriptExecution [CP-User] [Hermes]`) because `ios/.xcode.env.local` hard-codes a *versioned* `NODE_BINARY=/opt/homebrew/Cellar/node/<ver>/bin/node` that disappears on the next `brew upgrade node`. Point it at the stable symlink: `echo 'export NODE_BINARY=/opt/homebrew/bin/node' > ios/.xcode.env.local`. ^[extracted]

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

Related: [[kori]], [[kori-navigation-architecture]], [[ios-permission-review-prompts]], [[ios26-scene-lifecycle-launch-crash]], [[icloud-synced-repo-breaks-codesign]].
