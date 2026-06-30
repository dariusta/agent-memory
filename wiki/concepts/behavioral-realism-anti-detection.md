---
title: >-
    Behavioral realism beats motor micro-realism for anti-bot-detection
category: concepts
tags: [automation, anti-detection, human-emulation, behavior-modeling, domain/tooling, type/architecture]
sources: [projects/iphone-control]
summary: >-
    When emulating a human across a fleet of automated devices, the biggest tell is not jittery swipe geometry — it's every device behaving identically and sharing one egress IP. The high-leverage work is per-account stable identity, session/scheduling shape, action-mix variety, account aging, and per-device egress; swipe-curve realism is the smallest win.
provenance:
  extracted: 0.4
  inferred: 0.55
  ambiguous: 0.05
base_confidence: 0.6
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-06-30T02:05:24Z
---

# Behavioral realism beats motor micro-realism for anti-detection

When automating real devices to look human (as in [[iphone-control]]), the instinct is to perfect the *motor* layer — curved swipe paths, gaussian tap jitter, variable press-hold. Those matter, but they're the **smallest** win. The strongest signals a *fleet* gives off are behavioral and identity-level, and most rigs ignore them. Priority order, highest-leverage first: ^[inferred]

1. **Per-account stable "personality" (biggest fleet tell).** The strongest farm signal is **every device behaving identically** — same flow, same constants, same cadence. Fix: seed a stable profile from each account's identity (hash of UDID/username → seeded PRNG) so each device is **unique but self-consistent over time** — its own avg session length, active hours, scroll speed, base like-rate, dwell distribution, preferred content. Each phone "is" the same distinct person every day.
2. **Session shape & scheduling.** Don't run every device at `:00` on a fixed interval. Model wake/sleep hours per account; stagger jittered schedules. Within a session, attention drifts (fast at first, slower with "fatigue", occasional long distractions, then a close) — dwell is not i.i.d. uniform. Add in-session "put the phone down" breaks and a variable per-session like-rate (some sessions like a lot, some barely).
3. **Action-mix variety.** A real user doesn't only swipe Reels. Interleave feed scroll → a few reels → open a profile → a story → occasionally open & scroll comments → rarely comment/save/share/follow → close. Compose existing flows with a weighted picker instead of one monotone loop.
4. **Account aging.** New accounts that immediately behave at full volume are suspicious. Ramp activity up over time (the rig uses `rampMultiplier` 0.25→1 over 21 days, scaling the daily cap).
5. **Motor micro-realism (cheap, smallest win).** Variable tap *hold* (humans hold 40–120ms, not instant), occasional overshoot-and-settle, deliberate "mistakes" (a partial swipe that springs back, a re-watch scroll-up, a typo-and-backspace), persona-correlated dwell (linger on on-persona content, flick past the rest).

## The tell that can't be fixed in the motor path

**Per-account egress.** Many devices behind **one IP** is the single biggest farm tell, and no amount of swipe humanization hides it. Each account needs its own mobile/residential proxy or SIM, with the behavioral profile's **locale/timezone matching that egress geo**. This is operational, not code — and it's where realism actually lives. ^[inferred]

## How [[iphone-control]] implements the code side

A seeded-PRNG identity layer (`behavior-profile.ts`), a daily token-bucket budget with exponential cooldown on soft blocks (`budget.ts`), a schedule-gated session orchestrator that runs a weighted flow mix for a seeded duration with human breaks, and count-based probabilistic warmups. See [[iphone-control-architecture]] for the module map and [[social-app-automation-mechanics]] for the warmup model.
