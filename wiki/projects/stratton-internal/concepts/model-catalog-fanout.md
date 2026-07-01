---
title: >-
    Model Catalog Fan-Out (adding/removing a generation model)
category: concepts
tags: [domain/ai, domain/web, type/architecture, project/stratton-internal, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Adding or removing one generation-model id touches ~15 synchronized sites; model-catalog.ts is the typed source of truth, but the live node menu comes from MuAPI, not the catalog — edit model-allowlist.ts to actually restrict it.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.72
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:39Z
updated: 2026-07-01T08:30:39Z
---

# Model Catalog Fan-Out

In stratton-internal ("mimic"), adding or removing a single AI generation model (e.g. dropping `kling-v3.0-pro-image-to-video`, adding `kling-v3-turbo-pro-image-to-video`) is **not** a one-file edit — the same model id is referenced across ~15 synchronized sites in code, agent prompts, skill-docs, and tests. Miss one and either a drift test fails or a preset/flow silently points at a removed model. See [[stratton-internal]] and the provider [[muapi]].

## The source of truth vs. what actually drives the menu

- **`packages/shared/src/model-catalog.ts`** is the *typed* single source of truth for every model the platform can use. Its own header names its consumers: **node dropdowns, the canvas-wiring guide, and prompt validators**. ^[extracted]
- **But the live Canvas node menu is NOT built from the catalog.** Per the header of `apps/web/lib/model-allowlist.ts`: the node menu is built from **MuAPI's live `/node-schemas` response, which returns MuAPI's entire ~400-model catalog**. Curating the local `utility.jsx` fallback does **not** restrict that menu — **`model-allowlist.ts` is the file that actually restricts which models the Canvas exposes.** ^[extracted]

This split is the biggest trap: editing the catalog or the `utility.jsx` fallback feels like removing a model, but the model still shows up in the live menu unless the allowlist is changed.

## The full site list (a single model id touches all of these)

- `packages/shared/src/model-catalog.ts` — typed catalog entry (+ "reference-only, not wired" entries that mention ids in prose).
- `apps/web/lib/model-allowlist.ts` — the real menu-restriction list.
- `apps/web/lib/model-duration.ts` — per-model duration coercion rules (see the MuAPI duration gotcha in [[muapi]]).
- `packages/workflow-builder/src/components/utility.jsx` — the `videoModels` fallback list (does not gate the menu).
- **WaveSpeed-routed models** — `isWaveSpeedModel()` is **duplicated in three files** (`packages/integrations/src/generation.ts`, `apps/web/lib/run-agent-canvas.ts`, `apps/web/app/api/workflow/[id]/node/[nodeId]/run/route.ts`), plus the model const/branch in `packages/integrations/src/wavespeed.ts` and its re-export in `packages/integrations/src/index.ts`. Remove/add in all of them. ^[extracted]
- **Agent prompt + presets** — `apps/web/app/api/agent/canvas-build/route.ts` (the canvas-build agent's model lists, `videoGuide()` map, lip-sync-repair section) and `apps/web/app/(dashboard)/workflow/WorkflowBrowser.tsx` (quick-build preset buttons that hardcode a model, e.g. the "Kling v3" and "Happy Horse" presets).
- **Skill-doc** — `packages/workflow-builder/src/skills/canvas-wiring.md` (the agent's model reference table) and `.../prompt-references/SOURCES.md`.
- **Tests** — `model-catalog.test.ts`, `prompt-rules/index.test.ts`, `scene-prompting.test.ts`, `scene-segment.test.ts`, `model-duration.test.ts`, `run-agent-canvas-providers.test.ts`, and a **`skills-drift.test.ts`** that enforces catalog ↔ allowlist ↔ skill-doc consistency.

## Working rules learned here

- **Verify the exact MuAPI slug and its `input_schema` before wiring**, via the MuAPI per-model endpoint — see [[muapi]]. A guessed id/family propagates the wrong string to all 15 sites.
- **Model family is matched by substring**, not exact id: `scene-prompting.ts` does `m.includes('kling')` → `'kling'` family, so a new `kling-*` id inherits the family guidance automatically. ^[extracted]
- **Duration**: a model with no explicit `model-duration.ts` rule rides the generic prefix rule (a `kling-` id → 5s/clip). Only add a rule if the model's valid set differs.
- **Presets are product behavior, not mechanical**: removing a model that a preset/default points at (AI Slop brainrot default = `grok-imagine-image-to-video`; quick-build buttons) requires a *product decision* on the replacement — ask, don't guess.
- **The drift + catalog integrity tests are your safety net** — after edits, a full-repo grep for the removed ids plus `bun run typecheck` + the affected vitest suites + `biome check` catches missed sites. (Beware the [[vitest-stale-worktree-pollution]] false failures when running from repo root.)
