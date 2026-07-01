---
title: >-
    Build-Agent Prompt-Reference System (Stratton)
category: concepts
tags: [domain/ai, type/architecture, visibility/internal, topic/prompting]
sources: [projects/stratton-internal]
summary: >-
    The build agent loads a per-model prompting guide (gpt-image / seedance-2 / happy-horse) as context, chosen by model prefix in canvas-build/route.ts; guides are prose-editable (drift test doesn't pin content), and each model wants a different prompt discipline.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:50Z
updated: 2026-07-01T08:29:50Z
---

# Build-Agent Prompt-Reference System (Stratton)

How the `run-agent-canvas` build agent knows *how to author* a prompt for whichever image/video model a node uses. The agent doesn't guess from training — it reads a **per-model prompting guide** injected as context. See [[stratton-internal]].

## Layout

Guides live under `packages/workflow-builder/src/skills/prompt-references/{image,video}/`. Each side has a `SKILL.md`, universal guides, and per-model `references/`: ^[extracted]

- **image/** — `references/gpt-image.md` (+ `gpt-image/breakdown.md`, `gpt-image/faq.md`), `references/nano-banana.md`, plus universal `references/golden-rules.md` and `references/prompt-framework.md`.
- **video/** — universal `references/vibe-creating.md`; per-model `references/seedance-2.md` (+ `seedance-2/breakdown.md`), `references/happy-horse.md`, `gemini-omni…`.

## How a guide reaches the agent

`apps/web/app/api/agent/canvas-build/route.ts` maps a **model name → guide file** and injects that file's prose as context. E.g. `if (model.startsWith('happy-horse')) return 'video/references/happy-horse.md';` (~L105), with a `HAPPY_HORSE_GUIDE = 'video/references/happy-horse.md'` constant (~L136). So a guide only shapes output when the selected model's prefix matches — it is *not* enough for the file to sit in the repo. ^[extracted]

## Editing guides is safe

`apps/web/__tests__/skills-drift.test.ts` only asserts each vendored subfolder **exists and contains a non-trivial `breakdown.md`/`guide.md`** — it does **not** hash or snapshot the prose. So you can rewrite a guide's wording to change agent behavior without breaking tests (markdown edits also can't affect typecheck). Verify with `bun vitest run apps/web/__tests__/skills-drift.test.ts`. ^[extracted]

## Per-model prompt discipline (they differ, and mixing them is a bug)

The core lesson of this project: **each model wants a different prompt shape**, and copying one model's rule onto another silently degrades output. The reusable cross-model principle is lifted to [[ai-video-model-prompt-discipline]].

- **GPT Image 2** (`gpt-image-2` prod default; migration-only `gpt-image-1.5`/`gpt-image-1`; budget `gpt-image-1-mini`). Not prompted like a classic diffusion model — it **follows detailed natural-language description**. 5-slot structure; rewards **concrete facts** (camera/lens, "phone front camera, mild motion blur, crushed shadows, sensor grain") over an **adjective-soup / mood-word tail** ("candid, authentic, unpolished aesthetic") which the anti-slop table flags as *degrading* GPT Image 2 specifically. The 5th **Constraints slot** (`no watermark, no extra text, no duplicate face, preserve product logo`) is "where most mediocre prompts fail silently." Also watch physical consistency (a "back-to-camera + mirror-selfie" brief is a geometry contradiction). Wiring gotcha: `run-agent-canvas.ts` requires gpt-image-2 resolution in **UPPERCASE** (`'1K'|'2K'|'4K'`). ^[extracted]
- **Seedance 2.0** (Stratton node `sd-2-omni-reference`) — "**rewards direction, not description**; write like a director handing a crew a shot list." **Hard reference rule:** identity/product come from `@image1`/`@image2` tokens — map **roles only, never re-describe appearance** (text↔image mismatch is the #1 cause of identity drift, wardrobe mixing, product-label glitches). Capped **4–8 s per node**; a 10–15 s UGC ad **must be split into multiple video nodes** ("do not pack a long ad into one 8-second cut"). VO pace ≈ **2.5 words/sec** (~38 words fit 15 s). ^[extracted]
- **Happy Horse 1.1** (`happy-horse-1.1-image-to-video-720p`) — **image-to-video**: a start frame is wired to `images_list` → `videoInput6`. Supports a **single continuous 3–15 s take with native lip-sync**, so it's the *right* model for "one continuous shot, no cuts + talking" (Seedance's 8 s cap would force cuts you don't want). `duration` / `aspect_ratio` / `resolution` are **node params, not prose**; keep only the *continuity cue* ("one continuous handheld take, no cuts") in text. Talking clips want explicit **lip-sync mouth mechanics** ("forms each word clearly, lips match the line"). Emoji section headers are filler tokens — use plain prose. ^[extracted]

## The Happy Horse guide fix (2026-07-01)

The Happy Horse guide had wrongly **imported Seedance's "role-only, animate-don't-reinvent, do NOT re-describe" rule** — which suppressed exactly the rich *descriptive-prose-plus-dialogue* prompts the pipeline should produce. The fix reframed the guide so descriptive+dialogue over a wired image is the **endorsed** style: ^[extracted]

- The wired image wins on **identity / face / exact product**, but you **should write the full scene in prose** (subject, wardrobe, setting, action, timed beats, quoted dialogue). Re-describing the subject does **not** hurt Happy Horse — it reinforces continuity. The only hard rule is **don't contradict the frame**. "**This is NOT Seedance**" — no `@image1` tokens.
- Kept two genuinely-useful constraints: an **exact look that must match** (nail color, a readable label) is **baked into the start frame first** (a nano-banana edit) so the video model *preserves* rather than *recolors* it (recoloring mid-clip = flicker/drift); and a **mid-clip wardrobe/location change = a second node** (one frame can't cleanly swap outfit/scene).
- Added **four working archetypes** to copy: **A** timed UGC/livestream product demo with dialogue; **B** two-reference talking demo (subject + product) with the frame-baked exact-detail caveat; **C** cinematic multi-shot commercial, no dialogue, ≤6 beats + per-model anchors; **D** single continuous cinematic atmospheric take.
