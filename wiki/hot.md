---
title: >-
    Hot — Working Memory
category: meta
summary: >-
    Fast-context scratchpad read first by wiki-query: recent activity, active threads, and key takeaways. Rewritten on every sync.
updated: 2026-07-01T00:11:40Z
---

# Hot — Working Memory

The first thing `wiki-query` reads. Keep it short and current.

## Recent Activity

- [2026-06-30] Synced **[[iphone-control]]** again (Session 6, HEAD `c557148`) — merged into [[social-app-automation-mechanics]] + [[ui-automation-matcher-cascade]]: the harness gained a deterministic **`replace_text`** field-edit primitive (tap → long-press → OCR "Select All" or backspace ×30 → type) that fixed the edit-profile flows the LLM kept flubbing; **two agent-recovery fixes** (raise the escalation step cap 12→60 via `FLOW_ESCALATE_MAX_STEPS`; strip "credentials/passwords/tokens/API keys" trigger words from the guard prompt that were tripping Claude's own safety filter); Wave 2 got a clean pass on all 6 IG+TT analytics flows; and the camera-roll thumbnail picker was flagged **still brittle** with a planned deterministic **`--media_index=N`**.
- [2026-06-30] Synced **[[kori]]** again — physical-iPhone install session (VC iPhone 17 Pro). Two new global skills: **[[ios26-scene-lifecycle-launch-crash]]** (iOS 26/27 SDK SIGTRAPs any app that declares a SceneManifest but never adopts UIScene — fixed by adding a SceneDelegate to the stock Expo/RN AppDelegate) and **[[icloud-synced-repo-breaks-codesign]]** (building in iCloud-synced `~/Documents` makes codesign reject `.appex`; use a `~/Library` derivedDataPath). Expanded [[kori-ios-build-run]] with the xcodebuild+devicectl device path.
- [2026-06-30] Synced **[[iphone-control]]** again — full-flow live-test campaign across all ~30 flows surfaced 3 new durable mechanics (merged into [[social-app-automation-mechanics]] + [[ui-automation-matcher-cascade]]): opening a profile from a *moving feed* defeats even the agent fallback (pause-first + CV avatar, not more escalation); IG insights/analytics need a **Professional/Creator** account; posting needs **pre-existing camera-roll media**.

## Active Threads

- **iphone-control** — esp32farm rig validated live on "Austin-hal" (iPhone XR, iOS 26.5). Live-test campaign progressing: **Wave 2 passed all 6 IG+TT analytics flows (0 escalated, 0¢)** and both edit-profile flows now PASS via the new `replace_text` primitive. Code-side open work: the **camera-roll thumbnail picker** (post/reel/story) is the top remaining brittle step — implement the deterministic **`--media_index=N`** to skip the LLM selection; the **moving-feed profile-open** flows (tiktok-follow, view-profile ×2) still need pause-first + a **CV avatar** landmark; instagram-comment needs the same region-tap focus fix the search got; a dynamic rail detector remains on the wish-list. Human open items: seed camera-roll media before posting tests, capture per-device CV templates, add a 2nd IG account (login handoff), and **rotate the Anthropic API key that leaked into the chat**.
- **kori** — now installs & runs on the VC iPhone 17 Pro (Release via `xcodebuild` + `devicectl`, since this Mac's Xcode-beta has no Simulator). A SceneDelegate was added to `AppDelegate.swift` to clear the iOS 26+ launch SIGTRAP. **Open discrepancy:** the earlier sim note claims the AppDelegate was *already* on UIScene, but the device session found it stock-legacy — recheck the committed `AppDelegate.swift`. Onboarding `social`/`notifications` steps still fire native iOS prompts invisible in dev. See [[kori-ios-build-run]].
- **stratton-internal infra** — staging shares the prod Trigger.dev worker/queue and prod Supabase DB.

## Key Takeaways

- **Behavioral/identity realism beats motor micro-realism for anti-detection.** The biggest fleet tell is every device behaving identically + many devices on one egress IP — not swipe geometry. Prioritize per-account seeded identity, scheduling, action-mix, account aging, and per-device proxy/SIM. → [[behavioral-realism-anti-detection]]
- **Deterministic-first, agent-last UI automation.** Tap via a cascade `template → region → OCR → LLM agent`; mark fragile taps optional; a *wrong* CV template is worse than none (it mis-locks NCC). **The whole cascade — agent included — assumes a static frame: a continuously-moving target (an avatar on a playing feed) needs a *pause*, not more escalation.** → [[ui-automation-matcher-cascade]]
- **Two LLM-UI-agent failures that masquerade as "bad matching":** (1) the recovery agent silently hits a **too-low step cap** mid-recovery — a *budget* failure, not a matching one (raise it, make it env-overridable); (2) the agent's own **guard/safety sub-prompt** that lists "credentials/passwords/tokens/API keys" **trips the model's safety filter** and makes it refuse — describe the constraint behaviorally instead of listing hot-button nouns. And for a rote edit the LLM keeps flubbing (clear+retype a field), add a **deterministic primitive** (`replace_text`) rather than a smarter prompt. → [[ui-automation-matcher-cascade]]
- **macOS 26 dropped the on-device Vision OCR models** (`Found bundles : { }`) — both legacy and modern Vision APIs fail; swap to a self-contained engine (RapidOCR/ONNX). → [[macos-vision-ocr-models-missing]]
- **`pymobiledevice3 dvt launch` doesn't wake the display** — DVT capture then reads a black frame and flows "time out" misleadingly. Wake first (`POST /home`); set Auto-Lock to Never. → [[dvt-launch-does-not-wake-display]]
- **2026 IG/TikTok specifics:** pause the playing feed before navigating (closed-loop pointer can't lock on motion); TikTok's account switcher is a *two-tap* sequence; IG Reels has no follow/favorite on the rail; **IG insights/analytics require a Professional (Creator) account**; **posting (post/story/reel) needs pre-existing camera-roll media**. → [[social-app-automation-mechanics]]
- **Native iOS prompts are invisible during testing** — `StoreReview.requestReview()` is suppressed outside App Store/TestFlight; the notification dialog fires once per install. → [[ios-permission-review-prompts]]
- **iOS 26/27 SDK hard-crashes "scene declared but not adopted."** An app whose Info.plist has a `UIApplicationSceneManifest` but still runs the legacy AppDelegate window lifecycle (stock Expo SDK 54 / RN 0.81) SIGTRAPs at launch (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`). Add a real SceneDelegate. → [[ios26-scene-lifecycle-launch-crash]]
- **Don't build Xcode app-extension projects inside iCloud-synced `~/Documents`** — iCloud stamps `com.apple.FinderInfo` on freshly-built `.appex` and codesign rejects it; it re-stamps mid-build so stripping fails. Point `-derivedDataPath` at `~/Library`. → [[icloud-synced-repo-breaks-codesign]]
- **Trigger.dev "TTL (10m) expired" = a job routed to the `dev` environment** (no persistent worker), chosen by the `TRIGGER_SECRET_KEY` prefix. → [[trigger-dev-environment-routing]]
