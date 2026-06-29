---
title: >-
    Stratton Internal (mimic)
category: projects
tags: [domain/web, domain/infra, domain/ai, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Next.js 15 app on Railway that generates AI UGC video ads ("run-agent-canvas"); background work runs on Trigger.dev; staging shares the prod Supabase DB.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-06-29
created: 2026-06-29T02:19:37Z
updated: 2026-06-29T02:19:37Z
---

# Stratton Internal (mimic)

Internal tool (codename **"mimic"**) that generates AI UGC-style video ads. The core flow is **`run-agent-canvas`**: it builds short ad videos, applies a "realism"/de-AI post-processing pass over the rendered output, and casts AI character voices (Fish Audio, VoxCPM, Seedance clone) — including a **voice-scrape** step that discovers real creators matching a character, isolates a clean clip, and saves it to a voice library.

Source CWD: `/Users/darius/Documents/Stratton/stratton-internal`.

## Architecture

- **Web app** — Next.js 15 (`apps/web/`), tested with Vitest using the `@/` path alias (run Vitest from `apps/web/` so the alias resolves). Monorepo also contains a `trigger/` package for background jobs.
- **Hosting — Railway**, not Coolify. The service is `stratton-internal` ("mimic internal"). There are separate **prod** and **staging** Railway environments. ^[extracted]
- **Background jobs — Trigger.dev** (SDK v4.4.6, project ref `proj_tpqkwtxauprzppsfxqno`). ~63 tasks: intake, posts, QC, canvas runs, voice scraping. The worker is deployed from `cd trigger && npx trigger deploy` (or `./trigger/deploy.sh`). See [[trigger-dev]].
- **Database — Supabase (Postgres).** Staging **shares the prod Supabase DB** (identical `DATABASE_URL`) — staging is not fully isolated from prod data. ^[extracted]
- **Media pipeline** — server-side ffmpeg post-processing (`apps/web/lib/video-postproc.ts`) plus a Remotion compositor; the Trigger worker container bundles ffmpeg + Remotion (its build takes a few minutes). External AI deps include Gemini (seen returning transient 503 `UNAVAILABLE`).

## Environment / config wiring

The Trigger.dev environment a job lands in is decided **entirely by the `TRIGGER_SECRET_KEY` prefix** on whichever client calls `tasks.trigger()` (no explicit `configure()` is used). `tr_prod_…` → prod env; `tr_dev_…` → dev env. This single env var is the seam where prod vs staging vs local diverge — see [[trigger-dev-environment-routing]].

## Incidents distilled (2026-06-28)

- **Video realism pass silently skipped on every run.** `video-postproc.ts` built an ffmpeg `curves` filter with `interp=pchip`, which only exists in ffmpeg ≥ 5.1; the prod container shipped an older ffmpeg, so the whole filter graph hard-failed and every post-process fell through to "skipped." General lesson + fix: [[ffmpeg-filter-version-compatibility]].
- **"Scrape & find voice" runs expired at 10m, never executed.** Root cause was a **config bug**, not code: the **staging** Railway service held a `tr_dev_…` `TRIGGER_SECRET_KEY`, routing all staging background jobs into the Trigger.dev *dev* environment (which has no persistent worker and a built-in 10-minute queue-TTL). Full diagnosis + the false-start it corrected: [[trigger-dev-environment-routing]]. Resolution: set staging's `TRIGGER_SECRET_KEY` to the prod key (staging already shares the prod DB) and redeploy the worker (it was stale at `v20260622.3` → `v20260629.1`, 63 tasks).

## Operational notes

- The deploy wrapper needs `set -a` before `source .env` so the loaded vars are **exported** to the child deploy script — without it `source .env` sets but doesn't export, and `trigger deploy` gets no key and fails.
- Iterative cloud-state diagnosis here is expensive — one such session ran ~$100. Inspect the actual Trigger dashboard / Railway state early instead of theorizing from symptoms.
