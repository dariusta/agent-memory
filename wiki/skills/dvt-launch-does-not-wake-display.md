---
title: >-
    pymobiledevice3 DVT launch doesn't wake the iPhone display
category: skills
tags: [ios, pymobiledevice3, dvt, automation, domain/tooling, type/howto]
sources: [projects/iphone-control]
summary: >-
    `pymobiledevice3 developer dvt launch <bundle>` starts the app process but does NOT wake a slept display, so DVT screen capture returns a near-black frame, OCR finds nothing, and every wait-for-screen step fails with misleading "timed out" errors. Wake the phone first and disable Auto-Lock for unattended runs.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.64
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-06-30T02:05:24Z
---

# pymobiledevice3 DVT launch doesn't wake the iPhone display

When a DVT-driven iOS automation flow fails with `timed out waiting for <screen>` even though the bundle id is correct and the app is installed, the cause is often **not** the flow — the **display is asleep**. ^[extracted]

`pymobiledevice3 developer dvt launch <bundle>` starts the app *process* but does **not** wake the screen. If the phone auto-slept, DVT screen capture renders the last/black framebuffer (just the status-bar clock still ticking, e.g. `6:21 SOS`), so OCR/CV sees nothing and every `wait_for_screen` / `succeed_if` step times out. The misleading part: the clock keeps ticking and the bundle launched, so it *looks* like the app just didn't load. ^[extracted]

Easy misdiagnoses to rule out (all wrong here): app navigated away, wrong bundle id, OCR signature mismatch, phone locked. The actual state is "display asleep, framebuffer black." ^[inferred]

## Fix

- **Wake the phone before launching any flow** — a hardware HOME press (in [[iphone-control]], `POST /home` to the ESP32 panel) wakes it and lands on the springboard.
- **Close the launch→first-frame gap.** Once a flow is moving, its own swipes/taps plus video playback (Reels / For You) keep the screen awake — so the danger window is just the slow first launch.
- **For unattended runs, set Auto-Lock to Never** (Settings ▸ Display & Brightness ▸ Auto-Lock) so the screen can't sleep mid-flow. This recurred across multiple flows (IG warmup, TikTok warmup) until Auto-Lock was disabled. ^[extracted]

See [[iphone-control-architecture]] for where this sits in the rig.
