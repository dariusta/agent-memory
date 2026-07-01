---
title: >-
    iphone-control (esp32farm)
category: projects
tags: [ios, automation, esp32, ble-hid, pymobiledevice3, ocr, computer-vision, instagram, tiktok, domain/tooling]
sources: [projects/iphone-control]
summary: >-
    A physical-iPhone automation farm that drives real devices over an ESP32 BLE-HID pointer + pymobiledevice3 DVT screen capture + RapidOCR/OpenCV vision, running humanized Instagram/TikTok "warmup" engagement flows with deterministic-first interactions and an LLM agent fallback.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.68
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-07-01T08:31:02Z
---

# iphone-control (esp32farm)

A **physical-device iPhone automation farm**. It drives *real* iPhones (not a simulator) to run social-media "warmup" engagement — watching/liking/following/favoriting/commenting on Instagram and TikTok feeds — while trying to behave like a real human so the accounts don't read as a bot farm. The working tree lives at `/Users/darius/Documents/Personal/iphone-control`; the rig code is under `esp32farm/`. The local fork ships **code but no runtime** (see [[iphone-control-architecture]] for the from-scratch setup). ^[extracted]

The reference device this session ran on: **"Austin-hal"** — iPhone XR, UDID `00008030-000A688C3C46202E`, 828×1792, iOS 26.5. ^[extracted]

## How it's wired (layers)

1. **Hardware** — a real iPhone on USB + an **ESP32 (CP2102, `/dev/cu.usbserial-0001`)** that presents as a **Bluetooth HID mouse+keyboard** to the phone. The Mac sends serial commands to the ESP32, which emits BLE HID events; the phone shows an AssistiveTouch pointer. ^[extracted]
2. **Screen capture** — `pymobiledevice3` **DVT** capture (needs a `remote tunneld`, which requires `sudo`). ^[extracted]
3. **Vision** — **RapidOCR** (bundled ONNX PP-OCR models) for text + **OpenCV** NCC template matching and circle detection for icons. Taps are **closed-loop**: capture → locate target → move pointer → re-capture to confirm → click. ^[extracted]
4. **Control panel** — a Flask server (`esp32farm/web/server.py`) on **:8770** exposing `/home`, `/find_image`, `/find_region`, `/extract_text`, swipe/tap/press, etc.; targets one device via `PHONEHID_UDID`/`PHONEHID_PORT`/`PHONEHID_NAME` env. ^[extracted]
5. **Flow engine** — TypeScript run with `tsx` (`esp32farm/flowengine`). ~30 registered flows (warmup, like-feed, switch-account, comment, view-profile, save, post, …). Entrypoints: `run-flow.ts <flow> --k=v`, `run-session.ts <accountId>`, `run-comment.ts`. ^[extracted]
6. **Humanization layer** — per-account behavioral profiles + session orchestration; see [[iphone-control-architecture]] and the global concept [[behavioral-realism-anti-detection]]. ^[extracted]
7. **Agent fallback** — every fragile interaction carries an `escalateGoal`; when a landmark moves or a popup appears, an LLM (Claude, via `agentic/harness.ts`, gated on `ANTHROPIC_API_KEY`) recovers. See the cascade in [[ui-automation-matcher-cascade]]. ^[extracted]

## Key project knowledge

- [[iphone-control-architecture]] — the full rig stack, the from-scratch runtime setup (venv/deps, RapidOCR swap, `server.py` fixes, panel/flow launch), and the per-account humanization module map.
- [[social-app-automation-mechanics]] — the app-version-specific mechanics learned live: TikTok account-switch two-tap sequence, pause-the-playing-video before navigating, IG Reels rail has no follow/favorite, count-based probabilistic warmup model, keyword→niche search prelude, and thread-aware "smart comment" generation.
- [[automated-login-2fa]] — the deterministic login/2FA subsystem: operator-opt-in gating (`FLOW_ALLOW_PASSWORD_LOGIN`), execution-time TOTP + email-OTP resolution, async `build()`, IMAP OTP fetch with a recency filter, IG's chained new-device email gate, and `add_account` mode.

## Reusable lessons that generalize (global pages)

- [[macos-vision-ocr-models-missing]] — macOS 26 dropped the on-device Vision text models (`Found bundles : { }`); the project rewired OCR to RapidOCR.
- [[dvt-launch-does-not-wake-display]] — `pymobiledevice3 dvt launch` starts the app but does **not** wake the screen → flows read a near-black frame and fail with misleading "timed out" errors; wake first.
- [[ui-automation-matcher-cascade]] — the deterministic-first `template → region → OCR → agent` matcher cascade, and why a *wrong* CV template is worse than none.
- [[behavioral-realism-anti-detection]] — the highest-leverage anti-detection work is behavioral/identity modeling (and per-account egress), not swipe-curve micro-realism.

## Login handling (operator-opt-in — the old "never login" rule was reversed)

**Earlier this was an absolute rule** ("the rig never types a password, submits a login, or enters a 2FA code — no automated login flow exists"). **That rule is gone.** The rig now has deterministic `instagram-login` / `tiktok-login` flows and an `add_account` mode, gated behind an **operator opt-in**: they refuse to start without `FLOW_ALLOW_PASSWORD_LOGIN=1`, and secrets come from **env vars, never chat**. Passwords/2FA codes are still never typed with the humanizer's typo jitter. Full mechanics — execution-time TOTP/OTP resolution, IMAP OTP with a recency filter, IG's chained email gate — are in [[automated-login-2fa]] (generalizable lessons: [[automating-2fa-code-entry]]). ^[extracted]
