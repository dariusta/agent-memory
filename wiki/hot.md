---
title: >-
    Hot — Working Memory
category: meta
summary: >-
    Fast-context scratchpad read first by wiki-query: recent activity, active threads, and key takeaways. Rewritten on every sync.
updated: 2026-06-30T02:05:24Z
---

# Hot — Working Memory

The first thing `wiki-query` reads. Keep it short and current.

## Recent Activity

- [2026-06-30] Synced **[[iphone-control]]** (first sync) — a physical-iPhone automation farm ("esp32farm") driving real devices via ESP32 BLE-HID + pymobiledevice3 DVT capture + RapidOCR/OpenCV to run humanized Instagram/TikTok warmup flows. Distilled the rig architecture, 2026 IG/TikTok automation mechanics, and 4 reusable lessons (macOS Vision OCR gap, DVT-no-wake, the matcher cascade, behavioral anti-detection).
- [2026-06-30] Synced **[[kori]]** again — iOS onboarding session (rating + notification permission prompts): the "native iOS prompts are invisible in dev" gotcha ([[ios-permission-review-prompts]]) + Kori's iOS build/run gotchas ([[kori-ios-build-run]]).
- [2026-06-29] Synced **[[stratton-internal]]** (first sync) — Next.js 15 / Railway app for AI UGC video ads on Trigger.dev.

## Active Threads

- **iphone-control** — esp32farm rig validated live on "Austin-hal" (iPhone XR, iOS 26.5): IG + TikTok warmups (plain + keyword/niche), TikTok account-switch end-to-end, and a real multi-video warmup that posted thread-aware comments. Open items are on the **human**: capture the per-device CV templates, finish adding a 2nd IG account (login handoff), and **rotate the Anthropic API key that leaked into the chat**. Code-side wish-list: a dynamic rail detector for the shifting TikTok/IG icon rails.
- **kori onboarding** — `social`/`notifications` steps fire native iOS prompts invisible in dev. See [[kori-ios-build-run]].
- **stratton-internal infra** — staging shares the prod Trigger.dev worker/queue and prod Supabase DB.

## Key Takeaways

- **Behavioral/identity realism beats motor micro-realism for anti-detection.** The biggest fleet tell is every device behaving identically + many devices on one egress IP — not swipe geometry. Prioritize per-account seeded identity, scheduling, action-mix, account aging, and per-device proxy/SIM. → [[behavioral-realism-anti-detection]]
- **Deterministic-first, agent-last UI automation.** Tap via a cascade `template → region → OCR → LLM agent`; mark fragile taps optional; a *wrong* CV template is worse than none (it mis-locks NCC). → [[ui-automation-matcher-cascade]]
- **macOS 26 dropped the on-device Vision OCR models** (`Found bundles : { }`) — both legacy and modern Vision APIs fail; swap to a self-contained engine (RapidOCR/ONNX). → [[macos-vision-ocr-models-missing]]
- **`pymobiledevice3 dvt launch` doesn't wake the display** — DVT capture then reads a black frame and flows "time out" misleadingly. Wake first (`POST /home`); set Auto-Lock to Never. → [[dvt-launch-does-not-wake-display]]
- **2026 IG/TikTok specifics:** pause the playing feed before navigating (closed-loop pointer can't lock on motion); TikTok's account switcher is a *two-tap* sequence; IG Reels has no follow/favorite on the rail. → [[social-app-automation-mechanics]]
- **Native iOS prompts are invisible during testing** — `StoreReview.requestReview()` is suppressed outside App Store/TestFlight; the notification dialog fires once per install. → [[ios-permission-review-prompts]]
- **Trigger.dev "TTL (10m) expired" = a job routed to the `dev` environment** (no persistent worker), chosen by the `TRIGGER_SECRET_KEY` prefix. → [[trigger-dev-environment-routing]]
