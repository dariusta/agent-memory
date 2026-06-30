---
title: >-
    Hot — Working Memory
category: meta
summary: >-
    Fast-context scratchpad read first by wiki-query: recent activity, active threads, and key takeaways. Rewritten on every sync.
updated: 2026-06-30T01:35:15Z
---

# Hot — Working Memory

The first thing `wiki-query` reads. Keep it short and current.

## Recent Activity

- [2026-06-30] Synced **[[kori]]** again — iOS onboarding session (rating + notification permission prompts). Distilled the "native iOS prompts are invisible in dev" gotcha + a Settings-fallback permission pattern ([[ios-permission-review-prompts]]), and Kori's iOS build/run gotchas ([[kori-ios-build-run]]).
- [2026-06-30] Synced **[[kori]]** (first sync) — React Native / Expo iOS Korean-learning app ("Korean Passport"), sibling Stratton project. Project overview + hybrid navigation model.
- [2026-06-29] Synced **[[stratton-internal]]** (first sync) — Next.js 15 / Railway app for AI UGC video ads on Trigger.dev. Two debugging incidents into reusable skills.

## Active Threads

- **kori onboarding** — the `social` (rating) and `notifications` steps in `Onboarding.tsx` fire native iOS prompts that never show in dev/simulator. Rating left native-only; notifications hardened with a real-permission-state branch + `Linking.openSettings()` fallback (`getNotificationPermissionState()` in `notificationUtils.ts`). Couldn't drive the sim end-to-end (Debug build crashes; sim UI automation unavailable on this Xcode-beta). See [[kori-ios-build-run]].
- **kori UI/UX** — Expo app where the home tabs are React state (`activeTab`), not routes. See [[kori-navigation-architecture]].
- **stratton-internal infra** — staging now shares the prod Trigger.dev worker/queue (repointed `TRIGGER_SECRET_KEY` to prod, redeployed `v20260629.1`), as it already shares the prod Supabase DB.

## Key Takeaways

- **Native iOS prompts are invisible during testing — don't chase a ghost.** `StoreReview.requestReview()` is suppressed outside App Store/TestFlight (and rate-limited ~3×/yr); the notification permission dialog only fires once per install. "No popup" is usually correct platform behavior, not a bug. Make permission steps branch on real state and deep-link to Settings when denied. → [[ios-permission-review-prompts]]
- **Kori's Debug dev-client build crashes at launch** — `expo-dev-launcher` can't find the `keyWindow` because `AppDelegate` was migrated to the UIScene lifecycle. Build **Release** (embeds JS, skips dev launcher) to run it. → [[kori-ios-build-run]]
- **Kori navigates two ways at once** — Expo Router file routes for full-screen pages, but the 5 home tabs are an `activeTab` React state in `Home.tsx`. Open a home tab with `setActiveTab('X')`, not a router push. → [[kori-navigation-architecture]]
- **Trigger.dev "TTL (10m) expired" = a job routed to the `dev` environment** (no persistent worker), chosen by the `TRIGGER_SECRET_KEY` prefix; the tell is *every* run expiring at 0ms. Fix the key/env, not a `ttl` knob. → [[trigger-dev-environment-routing]]
- **FFmpeg filter options are version-gated** — an option missing from the prod binary (e.g. `curves interp=pchip`, ffmpeg 5.1+) fails the *whole* graph; validate chains against the deploy ffmpeg. → [[ffmpeg-filter-version-compatibility]]
