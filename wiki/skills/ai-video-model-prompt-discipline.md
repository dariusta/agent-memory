---
title: >-
    Don't Cross Prompt Disciplines Between AI Video Models
category: skills
tags: [domain/ai, type/gotcha, topic/prompting, topic/video-gen]
sources: [projects/stratton-internal]
summary: >-
    Reference-token video models (Seedance @image1) want role-only refs and short split cuts; image-to-video models (Happy Horse) want full descriptive prose+dialogue over a wired start frame — applying one's rule to the other silently degrades output.
provenance:
  extracted: 0.5
  inferred: 0.45
  ambiguous: 0.05
base_confidence: 0.58
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:50Z
updated: 2026-07-01T08:29:50Z
---

# Don't Cross Prompt Disciplines Between AI Video Models

Different generative video/image models reward **opposite** prompt shapes. A prompt (or a house style-guide) tuned for one model can *silently degrade* another — the output still generates, just worse, so nobody notices the mismatch. Seen concretely in [[build-agent-prompt-references]] where a Happy Horse guide had inherited Seedance's rules and stopped producing the prompts the team wanted.

## The two families

- **Reference-token models** (e.g. Seedance 2.0 `@image1`/`@image2`): identity and product come from the *tokens*. Rule = **map roles only, never re-describe appearance in text** — text↔image mismatch is the top cause of identity drift, wardrobe mixing, and label glitches. They also cap short (≈4–8 s/cut), so a long ad is **split into multiple nodes**, written like a director's shot list. ^[inferred]
- **Image-to-video models** (e.g. Happy Horse: wired start frame → single continuous take with lip-sync): the frame owns identity, but you **write the full scene in descriptive prose + quoted dialogue**. Re-describing the subject *helps* continuity; the only hard rule is **don't contradict the frame**. These can hold one continuous 3–15 s take, so they're the right pick when the brief says "no cuts + talking." ^[inferred]

## Reusable rules of thumb

- **Bake an exact look into the start frame, don't ask the video model to change it.** A must-match detail (a specific nail color, a legible product label/logo) should be produced in the *start frame* (an image edit) first, so the video model **preserves** it. Asking the model to recolor/relabel mid-clip causes flicker and drift. ^[inferred]
- **A mid-clip wardrobe or location change is a new node/frame,** not a beat inside one generation — a single animated frame can't cleanly swap outfit or scene. ^[inferred]
- **Voice-over pace ≈ 2.5 words/sec.** ~38 words fill a 15 s clip; an over-packed line (50–65 words) rushes, clips, or desyncs. Trim it or spread it across cuts / silent b-roll windows. ^[extracted]
- **Duration / aspect ratio / resolution are node params, not prompt prose.** Keep only the *continuity cue* ("one continuous handheld take, no cuts") in text; the numbers belong in the node config. ^[inferred]
- **Concrete camera/physical facts beat mood-word tails.** "shot on a phone front camera, mild motion blur, crushed shadows, sensor grain" outperforms an "authentic, candid, unpolished aesthetic" adjective stack — the latter reads as slop to a description-following model. ^[inferred]

Related: [[build-agent-prompt-references]], [[stratton-internal]].
