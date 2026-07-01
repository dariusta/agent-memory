---
title: >-
    MuAPI
category: entities
tags: [domain/ai, type/service, project/stratton-internal, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    MuAPI is stratton-internal's primary generation-model provider (video + image); its live ~400-model /node-schemas response drives the Canvas node menu, and durations are validated server-side but NOT exposed in input_schema.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:39Z
updated: 2026-07-01T08:30:39Z
---

# MuAPI

Third-party aggregator of AI generation models (image + video: Kling, Grok Imagine, Wan, Sora, Veo, Gemini Omni, Seedance, etc.), and the **primary generation-model provider** for stratton-internal's Canvas. Key `MUAPI_API_KEY` (in `.env`/`.env.local`). See [[stratton-internal]] and [[model-catalog-fanout]].

## The live catalog drives the node menu

MuAPI exposes its **entire ~400-model catalog** via a live **`/node-schemas`** response, and the Canvas node menu is built **directly from that response** — not from the app's typed `model-catalog.ts`. Consequence: to restrict which models a user can pick, you edit `apps/web/lib/model-allowlist.ts`; curating the local `utility.jsx` fallback does **not** restrict the live menu. ^[extracted]

## Per-model metadata endpoint (use before wiring a new model)

```
GET https://api.muapi.ai/api/v1/models/<model-id>
Header: x-api-key: <MUAPI_API_KEY>
```

Returns: `name, description, category` (e.g. "Image to Video"), `family` (e.g. `kling-v3.0`), `group_of` (`video`/`image`), `cost` + `cost_currency`/`cost_strategy`/`dynamic_pricing`, `endpoint`, `estimate_endpoint`, and `input_schema`/`output_schema`. **Call this to confirm the exact slug and input params before wiring** — a guessed id/family then fans out wrong across the whole catalog (see [[model-catalog-fanout]]). Example confirmed here: `kling-v3-turbo-pro-image-to-video` → i2v, params `image_url` + `prompt` + `duration` (3–15, default 5), 1080p, family `kling-v3.0`.

## Duration gotcha (why `model-duration.ts` exists)

MuAPI **video models validate `duration` against a fixed per-model set at run time, but their `input_schema` does NOT expose that set** — it reports a *misleading* `minValue`/`maxValue`/`step` range. So a duration valid for one model (e.g. gemini-omni's default 6) 400s on another (sd-2 wants 5/10/15). The app therefore **hardcodes** valid durations per model in `apps/web/lib/model-duration.ts` (`coerceDuration`) rather than trusting the schema. ^[extracted]

## Related

- [[model-catalog-fanout]] — how a MuAPI model id fans out across the codebase.
- WaveSpeed is a *separate* provider that routes a few models (e.g. the old Wan 2.6 i2v) around MuAPI via `isWaveSpeedModel()`.
