---
title: >-
    iphone-control rig architecture & runtime setup
category: concepts
tags: [ios, automation, esp32, pymobiledevice3, rapidocr, flask, typescript, domain/tooling, type/architecture]
sources: [projects/iphone-control]
summary: >-
    The esp32farm layered stack (ESP32 BLE-HID → DVT capture → RapidOCR/OpenCV → Flask panel → tsx flow engine → per-account humanization → LLM fallback), how to bring the runtime up from a code-only fork, and the per-account behavior module map.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-06-30T02:05:24Z
---

# iphone-control rig architecture & runtime setup

See [[iphone-control]] for the project overview. This page captures the stack details and the non-obvious setup that took most of a session to get right.

## Bringing up the runtime (the fork ships code, not runtime)

The local fork's `SKILL.md` references upstream `/Users/vyct/...` paths that don't exist here. To run from scratch: ^[extracted]

- **venv** at repo root (system python 3.13). Install `pymobiledevice3 opencv-python numpy pyserial flask` + `rapidocr_onnxruntime onnxruntime`. `npm install` in `esp32farm/flowengine` for the flow engine.
- **OCR was rewired to RapidOCR** — `esp32farm/web/vision.py:ocr_blocks` calls a cached `rapidocr_onnxruntime.RapidOCR` (~0.6s/frame) instead of the dead Swift `mac/ocr` binary. Why: [[macos-vision-ocr-models-missing]].
- **`server.py` fixes:** `PMD` binary now reads `os.environ['PMD_BIN']` (was a hardcoded vyct path); the calibration loader now accepts autocal's nested `{calibrations:{NAME:...}}` layout (it previously only read the flat format that `tapper.py` writes — the two tools disagreed on the config shape). ^[ambiguous]
- **`remote tunneld` needs `sudo`** and cannot be started by the agent (password prompt). The human runs `sudo .venv/bin/python -m pymobiledevice3 remote tunneld` and leaves it running; its API is at `http://127.0.0.1:49151`.
- **Panel** (targets one device): `PHONEHID_UDID=… PHONEHID_PORT=/dev/cu.usbserial-0001 PHONEHID_NAME=Austin-hal PMD_BIN=<repo>/.venv/bin/pymobiledevice3 .venv/bin/python esp32farm/web/server.py` → serves on `:8770`.
- **Run a flow:** `cd esp32farm/flowengine && FLOW_PANEL_URL=http://127.0.0.1:8770 npx tsx run-flow.ts <flow> --key=val`.

**Operational gotcha that breaks every run if missed:** [[dvt-launch-does-not-wake-display]] — wake the phone (`POST /home`) before launching, and set Auto-Lock to Never for unattended runs.

## Interaction model

Taps are not coordinate-blind — they're **closed-loop via an AssistiveTouch pointer**: the Mac drives the ESP32 BLE-HID mouse to move the pointer, captures the screen, locates the pointer + target, and corrects until the click lands. This is robust on static screens but **fails over motion** (a playing video) because the pointer detector can't lock against moving content — the root cause of several TikTok nav failures (see [[social-app-automation-mechanics]]). ^[inferred]

Element targeting goes through the cascade in [[ui-automation-matcher-cascade]]: captured CV template → fractional region anchor → OCR label → LLM agent.

## Per-account humanization module map

Added to `esp32farm/flowengine` as a behavioral layer over the motor primitives (the *concept* and rationale live in [[behavioral-realism-anti-detection]]; this is the code map): ^[extracted]

| Module | Role |
|---|---|
| `flows/rng.ts` | Seeded PRNG (mulberry32 + xmur3 hash) → per-account identity stable run-to-run. |
| `flows/behavior-profile.ts` | `deriveProfile(accountId)` → active-hour curve, session length, like-rate, dwell mean/sd, scroll speed, breaks, typo-rate, tap-hold, timezone/locale, daily cap + **account-aging `rampMultiplier` (0.25→1 over 21 days)** + `shouldRunNow` schedule gate. |
| `flows/budget.ts` | Per-account daily token bucket + exponential cooldown on soft blocks (pure reducers). |
| `flows/store.ts` | Persists profiles → `~/.phonehid_farm_behavior.json`, budgets → `~/.phonehid_farm_budget.json`, captured CV templates → `~/.phonehid_farm_icons.json`. |
| `flows/session.ts` + `run-session.ts` | Orchestrator: schedule-gates, exports the account's dwell/typo profile via env (`FLOW_DWELL_MEAN/SD`, `FLOW_SCROLL_SPEED`, `FLOW_TYPO_RATE`), runs a weighted **mix** of flows for a seeded duration with human breaks + budget. |
| `flows/humanize.ts` | `swipePause`, `reelDwell`, `maybeBreakMs`, `sessionLikeRate`, `gaussMs`, `typingPlan` (typo + backspace correction; never on secrets). |

Motor-level humanization lives lower down: `server.py` `swipe()`/`flick()` use a randomized column/span/drift + half-sine **curved** path + non-uniform velocity; taps use a variable touch-down→hold→up (`_hold_click`) instead of an instant synthetic `CLICK`. Typing is genuine per-character HID keystrokes at 40–60 WPM with word gaps and "thinking" pauses — it types it out, never pastes. ^[extracted]
