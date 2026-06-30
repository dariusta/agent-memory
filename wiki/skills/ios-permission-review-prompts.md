---
title: >-
    iOS permission & review prompts don't fire in dev — and how to always do something visible
category: skills
tags: [ios, expo, react-native, permissions, storekit, type/howto]
sources: [projects/kori]
summary: >-
    Native iOS review (SKStoreReview) and notification-permission dialogs are silently suppressed in dev/simulator or after the first install, so "the popup never shows" is usually correct platform behavior, not a bug. Branch on real permission state with a Settings deep-link fallback so the step always does something.
provenance:
  extracted: 0.5
  inferred: 0.45
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T01:35:15Z
updated: 2026-06-30T01:35:15Z
---

# iOS permission & review prompts don't fire in dev

When an onboarding "rate us" or "enable notifications" step shows no popup, the first instinct is "the code is wrong." For two specific native iOS prompts the more likely cause is **platform behavior that makes the prompt invisible during testing** — the code can be perfectly correct and you'll still see nothing. Don't rewrite the wiring before ruling this out.

## The two ghosts

1. **App rating — `StoreReview.requestReview()` / `SKStoreReviewController`.** Apple **silently suppresses** this outside an App Store / TestFlight build (dev, Expo dev-client, and plain simulator builds never show it). Even in production it is **rate-limited to ~3 prompts per device per year** and Apple may choose not to show it at all. So a dev build will *never* display it no matter how the code reads. To actually see it: ship a TestFlight/App Store build. ^[inferred]
2. **Notification permission — `Notifications.requestPermissionsAsync()`.** The iOS system permission dialog appears **once per install**. If the user already granted *or* denied on a prior run, the call returns silently (no popup). To re-test the fresh dialog: delete the app from the simulator/device first, or reset its permissions in iOS Settings. ^[inferred]

The tell for both: nothing visibly happens, yet the function is being called and doesn't error. That's "working as designed," not a regression.

## The fix: branch on the real permission state

A permission step that silently no-ops (because permission was already denied) feels broken to the user. Make it **always do something visible** by reading the real state first and branching:

- Read status **without prompting** — `getPermissionsAsync()` returns `status` + `canAskAgain`. Wrap it in a small helper (e.g. `getNotificationPermissionState()`) so callers get a clean tri-state. ^[extracted]
- **Undetermined / can ask** → call `requestPermissionsAsync()` to show the native dialog (the normal path). ^[extracted]
- **Already granted** → proceed silently. ^[extracted]
- **Previously denied** (iOS won't re-prompt) → show your own alert ("Turn on notifications") that deep-links to the app's settings via `Linking.openSettings()`. Now the step does something instead of dying quietly. ^[extracted]

This pattern generalizes to any iOS permission (camera, mic, location): *check → request-if-undetermined → Settings-deeplink-if-denied*.

## Where this came from

Diagnosed in [[kori]]'s onboarding: the `social` (rating) step and `notifications` step were already correctly wired, but invisible in the simulator. The rating step was left native-only (correct for production); the notifications step got the Settings-fallback branch above. See [[kori-ios-build-run]] for why even building/running to reach those steps was non-trivial.
