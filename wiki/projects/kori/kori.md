---
title: >-
    Kori
category: projects
tags: [react-native, expo, expo-router, firebase, mobile, korean, stratton]
sources: [projects/kori]
summary: >-
    Kori — a React Native / Expo iOS app for learning Korean, gamified as a "Korean Passport". Hybrid navigation: Expo Router file routes for full-screen pages + an in-component tab switcher for the 5 home tabs.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.72
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T00:36:24Z
updated: 2026-06-30T04:22:30Z
---

# Kori

Kori is a **React Native / Expo** mobile app (iOS-focused) for learning Korean, gamified around a **"Korean Passport"** metaphor — a passport ID, a "Seoul Journey" path, badges, a virtual closet, and a streak calendar. It lives at `/Users/darius/Documents/Stratton/kori` and is a **sibling project to [[stratton-internal]]** under the same Stratton umbrella (the two are otherwise distinct codebases).

## Stack

- **Expo + Expo Router** — file-based routing under `app/` (`app/_layout.tsx`, `app/settings.tsx`, `app/lesson.tsx`, `app/daily-quiz.tsx`, `app/tutor.tsx`, `app/community.tsx`, `app/voice.tsx`, …). ^[extracted]
- **Firebase** — `GoogleService-Info.plist`, `.firebaserc`, `.firebase/` (auth/backend). ^[extracted]
- **Superwall** — paywall (`app/superwall/redeem.tsx`, `.superwall/`, debug paywall screens). ^[extracted]
- **i18n** (`app/i18n.js`), a **RemoteConfig** context (`src/contexts/RemoteConfigContext.tsx`), and a typed **analytics events** layer (`src/constants/analyticsEvents.ts`, `track(...)` / `trackScreen(...)`). ^[extracted]
- TypeScript throughout; typecheck with `npx tsc --noEmit -p tsconfig.json`. ^[extracted]

## Code layout

- `app/` — Expo Router full-screen routes (settings, lessons, quizzes, tutor, community, voice, object-capture, …).
- `src/components/` — shared UI: `Home.tsx` (the home shell), `BottomTabs.tsx`, `HapticTab.tsx`, `KoriMascot`, `LoginScreen.tsx`.
- `src/features/` — feature modules: `home/` (`LearnTab`, `SpeakTab`, `ProfileTab`), `progress/`, `vocab/`, `dailyWord/`, `review/`, `lessons/`, `conversation/`.
- `src/data/korean/` — lesson/content data (`units/*.json`, `formality.ts`).
- `src/design-system/`, `src/theme/`, `src/hooks/`, `src/utils/`.

## Key concepts

- [[kori-navigation-architecture]] — the app mixes **two** navigation models: Expo Router file routes for full-screen pages, and an in-`Home.tsx` `activeTab` React-state switcher for the five home tabs (`Home`/`Learn`/`Speak`/`Rewards`/`Profile`). Knowing which model a destination uses is the difference between `router.push('/x')` and `setActiveTab('X')`. ^[inferred]
- The **Profile** screen is the "Korean Passport" `ProfileTab` (`src/features/home/ProfileTab.tsx`) — it is a home tab, not a route. The home-header avatar opens it via `setActiveTab('Profile')`. ^[extracted]
- [[kori-ios-build-run]] — building/running Kori is non-trivial. On a **physical iPhone** (this Mac's Xcode-beta has no Simulator) build Release directly with `xcodebuild` + `devicectl`; the first device launch SIGTRAP'd on the [[ios26-scene-lifecycle-launch-crash]] until a SceneDelegate was added; and the iCloud-synced repo forces an out-of-tree derivedDataPath ([[icloud-synced-repo-breaks-codesign]]). On a **simulator** the Debug dev-client crashes (`expo-dev-launcher` keyWindow), so build Release; plus DerivedData-cache and sim-automation gotchas. ^[extracted]

## Onboarding

The onboarding lives in `src/components/Onboarding.tsx` (steps include `social` = app rating and `notifications`). Both the rating prompt and the notifications permission prompt are **native iOS prompts that are invisible during dev/simulator testing** — see [[ios-permission-review-prompts]]. The notifications step was hardened to branch on real permission state with a Settings deep-link fallback (`getNotificationPermissionState()` in `src/utils/notificationUtils.ts`); the rating step is left native-only (correct for production). ^[extracted]
