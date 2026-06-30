---
title: >-
    iOS 26+ SDK UIScene-lifecycle launch crash (NoSceneLifecycleAdoption SIGTRAP)
category: skills
tags: [ios, uikit, uiscene, scenedelegate, expo, react-native, xcode, crash, type/howto]
sources: [projects/kori]
summary: >-
    Building any app against the iOS 26/27 SDK hard-crashes at launch (EXC_BREAKPOINT/SIGTRAP in _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption) if Info.plist declares UIApplicationSceneManifest but the app never adopts the UIScene lifecycle. Fix: add a real SceneDelegate.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T04:22:30Z
updated: 2026-06-30T04:22:30Z
---

# iOS 26+ SDK UIScene-lifecycle launch crash

When you **build against the iOS 26+ SDK** (e.g. the only Xcode on the machine is the 27.0 beta), UIKit **hard-crashes the app at launch** if its `Info.plist` declares a `UIApplicationSceneManifest` but the app doesn't actually adopt the UIScene lifecycle. The crash is silent to the user — the icon is tapped and the app "instantly closes." ^[extracted]

## How it presents

- The app **launches and dies within ~1 second**; no Obj-C exception. ^[extracted]
- The crash report (`idevicecrashreport`, or Xcode device logs) shows **`EXC_BREAKPOINT` / `SIGTRAP`** (signal 5 — a native fatal, not a JS error), and the crashing frame is:
  ```
  ___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke
  ```
- These `…RuntimeIssue…` crashes embed a **human-readable explanation** in the crash report's diagnostic text — read past the backtrace; UIKit tells you exactly what it wants. ^[extracted]

## Root cause

UIKit on the iOS 26+ SDK treats "`UIApplicationSceneManifest` present **but** no scene actually connected" as a hard error, not a warning. A bare manifest with only `UIApplicationSupportsMultipleScenes=false` and **no `UISceneConfigurations` / no `SceneDelegate`** counts as "declared but not adopted." ^[extracted] Apps still on the **legacy AppDelegate window lifecycle** (which includes stock **Expo SDK 54 / React Native 0.81** templates, and many older native apps) trip this the moment they're compiled against the new SDK — even though the identical source ran fine on the iOS 18 SDK. ^[inferred]

## Fix — adopt the UIScene lifecycle

1. Complete the scene manifest in `Info.plist` — add `UISceneConfigurations` → `UIWindowSceneSessionRoleApplication` with a delegate class name (for RN/Expo, point it at `$(PRODUCT_MODULE_NAME).SceneDelegate`).
2. Move **window creation + root-view startup out of `AppDelegate.didFinishLaunching`** into a `SceneDelegate`'s `scene(_:willConnectTo:options:)`. Create `UIWindow(windowScene:)`, then hand it to your existing RN bootstrap.
3. Add `application(_:configurationForConnecting:options:)` to the AppDelegate returning a `UISceneConfiguration` for that role.

For React Native, `factory.startReactNative(withModuleName:in:launchOptions:)` (the window-taking overload, `startReactNativeWithModuleName:inWindow:launchOptions:`) already calls `makeKeyAndVisible` internally — so the SceneDelegate just supplies a window from the scene and calls it; you don't re-`makeKeyAndVisible`. ^[extracted]

Implementation tips that keep the diff small (learned on [[kori]]): ^[inferred]
- **Define the `SceneDelegate` class in the same `AppDelegate.swift` file** so it gets compiled without touching `project.pbxproj`.
- For an **Expo** app, also persist the scene manifest into `app.json` (`ios.infoPlist.UIApplicationSceneManifest`) so a future `expo prebuild` doesn't regenerate an Info.plist that reintroduces the crash.

## Related

- [[kori-ios-build-run]] — where this was diagnosed and fixed on a physical device.
- Note the *inverse* failure mode: an app **already** on a SceneDelegate can crash a tool that still expects the AppDelegate window — e.g. `expo-dev-launcher`'s "Cannot find the keyWindow" in Debug. See [[kori-ios-build-run]].
- [[icloud-synced-repo-breaks-codesign]] — a sibling iOS-build gotcha hit in the same session.
