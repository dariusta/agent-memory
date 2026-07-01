---
title: >-
    Deterministic-first UI automation: the template → region → OCR → agent cascade
category: skills
tags: [automation, computer-vision, ocr, llm-agent, reliability, domain/tooling, type/pattern]
sources: [projects/iphone-control]
summary: >-
    A reliability pattern for tapping UI elements whose position/label shifts: try the cheapest deterministic matcher first (captured CV template → fractional region anchor → OCR label) and only escalate to an LLM agent as last resort. Mark optional taps so a miss never fails the flow — and never ship a wrong template, since it actively mis-locks. The whole cascade (agent included) assumes a roughly-static frame; a continuously-moving target needs a pause, not more escalation. When you do escalate, give the agent enough steps (a low cap looks like a matching failure) and keep its guard prompt free of trigger words that trip the model's safety filter; and prefer a deterministic primitive over the agent for rote edits (see replace_text).
provenance:
  extracted: 0.55
  inferred: 0.4
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-07-01T00:11:40Z
---

# Deterministic-first UI automation: the matcher cascade

When automating a UI you don't control (a third-party app), no single way of locating an element is reliable: text-only OCR misses text-less icons, fixed coordinates drift as the layout shifts, and an LLM agent on every tap is slow and expensive. The robust design is a **cascade that tries the cheapest, most deterministic matcher first and escalates only on miss**. From [[iphone-control]] (`uiTap(platform, element)`): ^[extracted]

```
captured CV template (NCC over whole screen) → fractional region anchor → OCR label → LLM agent (escalateGoal)
```

- **Template (CV)** — a real captured crop of the icon, NCC-matched across the screen. Most precise and layout-robust *when the element looks stable*; e.g. it solves "the bookmark shifts per video" because it searches the whole frame, not a fixed point.
- **Region anchor** — a fractional `{xf, yf}` position. Always works as a backbone with no assets; the deterministic floor.
- **OCR label** — match the element's text (for labelled controls).
- **Agent** — an LLM with an `escalateGoal` that recovers when a landmark moved or a popup appeared (e.g. an accidental "TikTok LIVE" popup). Gated on an API key; off → the tap hard-fails instead of self-healing.

Add an element to a shared map once (its template + region + labels) and every flow can target it.

## Two hard-won rules

1. **A *wrong* template is worse than none.** Fixed-anchor auto-capture only works for elements at **stable** positions. Where the rail shifts (TikTok's upper follow/like/comment, all of IG Reels' rail where anchors land on the engagement *counts* like "221K" above the glyph), the crop catches the wrong glyph — and NCC will then confidently lock onto the wrong icon. **Verify every captured crop; drop the bad ones** and let them fall back to region→OCR→agent. ^[extracted]
2. **Make fragile taps `optional`** so a miss is a no-op, never a flow failure — best-effort engagement (follow/favorite) should silently skip when the control isn't readable rather than aborting the whole session. ^[extracted]

## Where it isn't enough

Fixed fractional anchors can't handle a rail whose icon *order/offset* changes per item. The real fix there is a **dynamic detector** (find the vertical column of icons, then map by order) rather than fixed fractions — a meaningful build, flagged as separate work. ^[inferred]

**The whole cascade — agent included — assumes a roughly-static frame.** A *continuously moving* target defeats every layer: NCC, region, and OCR all read a frame that's already stale by the tap, and the agent can't reason over motion either. In a live wave, every flow that opened the author's profile from a playing feed (`tiktok-follow`, `tiktok-view-profile`, `instagram-view-profile`) failed and the agent could not recover. The fix is **not more escalation** — it's to **pause the motion first** (then the cascade works normally). See [[social-app-automation-mechanics]]. ^[extracted]

## Making the escalation agent actually recover

When you *do* fall through to the agent, two non-obvious things kept it from finishing its recovery — both worth checking in any LLM-agent tool loop: ^[extracted]

1. **Give it enough steps.** The agent was silently bailing mid-recovery because its per-flow step cap was too low (12). A multi-step recovery (dismiss a popup → re-find the landmark → tap) can easily need more than a dozen tool calls. Session 6 raised it to **60** (overridable via `FLOW_ESCALATE_MAX_STEPS`). A recovery agent that hits its cap looks like a *matching* failure but is really a *budget* failure — inspect the step count before blaming the matcher.
2. **Watch your own guard prompt's vocabulary.** The flow's internal safety-check prompt literally enumerated *"credentials / passwords / tokens / API keys"* — and that word list **tripped Claude's own safety filter**, making the agent refuse/bail. Rephrasing to the same intent *without* the trigger words cleared it. Lesson: a meta/guard sub-prompt that names sensitive categories can get caught by the model's safety layer; describe the constraint behaviorally instead of listing hot-button nouns. ^[extracted]

## Prefer a deterministic primitive over the agent for fiddly edits

The agent is the last resort for *locating* a shifting element. For a **fixed mechanical sequence** the LLM keeps flubbing — e.g. clearing and retyping a text field — the better move isn't a smarter agent prompt, it's a new deterministic harness primitive. [[social-app-automation-mechanics#Replacing a field's contents (not just focusing it)|`replace_text`]] (tap → long-press → OCR "Select All" or backspace ×N → type) replaced repeated agent failures on edit-profile flows with one reliable step. Same philosophy as the cascade: escalate to the LLM only for genuine ambiguity, never for a rote sequence. ^[extracted]

Related: pausing a playing video before tapping (so a closed-loop pointer can lock) is a complementary trick — see [[social-app-automation-mechanics]].
