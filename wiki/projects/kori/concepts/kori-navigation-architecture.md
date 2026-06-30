---
title: >-
    Kori Navigation Architecture (hybrid: Expo Router routes + in-component tabs)
category: concepts
tags: [react-native, expo-router, navigation, state, kori]
sources: [projects/kori]
summary: >-
    Kori navigates two ways at once — Expo Router file routes for full-screen pages, and an `activeTab` React state in Home.tsx for the 5 home tabs. To open a home tab you set state, not push a route.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T00:36:24Z
updated: 2026-06-30T00:36:24Z
---

# Kori Navigation Architecture

[[kori]] uses **two navigation systems side by side**, and the non-obvious part is knowing which one a given destination belongs to.

## The two systems

1. **Expo Router file routes** (`app/*.tsx`) — for full-screen pages: `settings`, `lesson`, `daily-quiz`, `tutor`, `community`, `voice`, etc. Reached by router navigation (e.g. `ProfileTab` routes to `/settings`). ^[extracted]
2. **In-component tab state** — the five "home" tabs are **not** routes. `src/components/Home.tsx` holds `const [activeTab, setActiveTab] = useState<KoriTab>('Home')` where `type KoriTab = 'Home' | 'Learn' | 'Speak' | 'Rewards' | 'Profile'`. The `BottomTabs` component receives `activeTab` and an `onSelect` that calls `setActiveTab`. Switching tabs is a **React state change**, not a router navigation. ^[extracted]

`Home.tsx` body-switches on `activeTab` (renders `LearnTab` / `SpeakTab` / `ProfileTab` from `src/features/home/`). Only `activeTab === 'Home'` shows the app header (`showAppHeader`). ^[extracted]

## The practical rule

- To send the user to a **full-screen page** → router-navigate to its `app/` route.
- To send the user to a **home tab** (Learn / Speak / Rewards / **Profile**) → call `setActiveTab('<Tab>')`. There is no `/profile` route to push. ^[inferred]

This is exactly how the home-header avatar was wired to open the profile: a `Pressable` whose `onPress` fires `setActiveTab('Profile')` (plus `Haptics.selectionAsync()` and a `track('kori_tab_selected', { tab: 'Profile', source: 'header_avatar' })` analytics event). A reflex to reach for the router here would fail — Profile is a tab, not a route. ^[extracted]

## Gotcha worth remembering

A header element that "should open a screen" was a plain non-interactive `<View>`; the target screen already existed as a home tab. The fix was **state wiring, not a new screen** — check whether the destination is already a tab/route before building anything. ^[inferred]

Related: [[kori]].
