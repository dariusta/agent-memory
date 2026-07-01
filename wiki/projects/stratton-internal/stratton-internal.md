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
updated: 2026-07-01T08:30:39Z
---

# Stratton Internal (mimic)

Internal tool (codename **"mimic"**) that generates AI UGC-style video ads. The core flow is **`run-agent-canvas`**: it builds short ad videos, applies a "realism"/de-AI post-processing pass over the rendered output, and casts AI character voices (Fish Audio, VoxCPM, Seedance clone) — including a **voice-scrape** step that discovers real creators matching a character, isolates a clean clip, and saves it to a voice library. See the full pipeline map + yield diagnosis in [[voice-scrape-isolation-pipeline]].

Source CWD: `/Users/darius/Documents/Stratton/stratton-internal`.

## Architecture

- **Web app** — Next.js 15 (`apps/web/`), tested with Vitest using the `@/` path alias (run Vitest from `apps/web/` so the alias resolves). Monorepo also contains a `trigger/` package for background jobs.
- **Hosting — Railway**, not Coolify. The service is `stratton-internal` ("mimic internal"). There are separate **prod** and **staging** Railway environments. ^[extracted]
- **Background jobs — Trigger.dev** (SDK v4.4.6, project ref `proj_tpqkwtxauprzppsfxqno`). ~63 tasks: intake, posts, QC, canvas runs, voice scraping. The worker is deployed from `cd trigger && npx trigger deploy` (or `./trigger/deploy.sh`). See [[trigger-dev]].
- **Database — Supabase (Postgres).** Staging **shares the prod Supabase DB** (identical `DATABASE_URL`) — staging is not fully isolated from prod data. ^[extracted]
- **Media pipeline** — server-side ffmpeg post-processing (`apps/web/lib/video-postproc.ts`) plus a Remotion compositor; the Trigger worker container bundles ffmpeg + Remotion (its build takes a few minutes). External AI deps include Gemini (seen returning transient 503 `UNAVAILABLE`).
- **Video URL resolution** — a produced video usually lives in the `video_assets` table, **not** `video_tasks.final_video_url`. Resolve any task's playable cut through the canonical `apps/web/lib/final-video.ts` (single `resolveFinalVideoUrl` / batch `resolveFinalVideoUrls`), never a single column. See [[video-url-resolution]].
- **Generation models — catalog vs. live menu.** Models come from [[muapi]] (a ~400-model provider). `packages/shared/src/model-catalog.ts` is the typed source of truth, but the Canvas node menu is built from **MuAPI's live `/node-schemas`**, so `apps/web/lib/model-allowlist.ts` is what actually restricts it. Adding/removing one model id fans out across ~15 code/prompt/skill-doc/test sites (a `skills-drift.test.ts` enforces consistency). See [[model-catalog-fanout]].

## Environment / config wiring

The Trigger.dev environment a job lands in is decided **entirely by the `TRIGGER_SECRET_KEY` prefix** on whichever client calls `tasks.trigger()` (no explicit `configure()` is used). `tr_prod_…` → prod env; `tr_dev_…` → dev env. This single env var is the seam where prod vs staging vs local diverge — see [[trigger-dev-environment-routing]].

## Integrations

- **Scrape Creators** ([[scrape-creators]]) — third-party API for scraping IG/TikTok posts & accounts, wrapped in `packages/integrations/src/scrape-creators.ts`. Powers post/account tracking, the "Mark posted → scrape" flow, and voice scraping. Its single-item fetch endpoints are **GET `?url=`**, not POST + JSON — see [[scrape-creators-get-endpoints]].

## AI prompt-reference system

The build agent authors image/video prompts by reading a **per-model prompting guide** injected as context, chosen by model prefix in `apps/web/app/api/agent/canvas-build/route.ts`. Guides live under `packages/workflow-builder/src/skills/prompt-references/{image,video}/references/` (`gpt-image.md`, `nano-banana.md`, `seedance-2.md`, `happy-horse.md`, plus universal `golden-rules.md` / `prompt-framework.md` / `vibe-creating.md`). The `skills-drift.test.ts` only checks these files exist and are non-trivial — it does **not** pin their prose, so a guide is safe to rewrite to change agent behavior. Each model wants a *different* prompt discipline (mixing them is a bug — a Happy Horse guide had wrongly inherited Seedance's role-only rule). Full architecture + per-model rules: [[build-agent-prompt-references]]; the reusable cross-model principle: [[ai-video-model-prompt-discipline]].

## Incidents distilled (2026-06-28)

- **Video realism pass silently skipped on every run.** `video-postproc.ts` built an ffmpeg `curves` filter with `interp=pchip`, which only exists in ffmpeg ≥ 5.1; the prod container shipped an older ffmpeg, so the whole filter graph hard-failed and every post-process fell through to "skipped." General lesson + fix: [[ffmpeg-filter-version-compatibility]].
- **"Scrape & find voice" runs expired at 10m, never executed.** Root cause was a **config bug**, not code: the **staging** Railway service held a `tr_dev_…` `TRIGGER_SECRET_KEY`, routing all staging background jobs into the Trigger.dev *dev* environment (which has no persistent worker and a built-in 10-minute queue-TTL). Full diagnosis + the false-start it corrected: [[trigger-dev-environment-routing]]. Resolution: set staging's `TRIGGER_SECRET_KEY` to the prod key (staging already shares the prod DB) and redeploy the worker (it was stale at `v20260622.3` → `v20260629.1`, 63 tasks).

## Incidents distilled (2026-06-29)

- **IG "Mark posted" scrapes 404'd with "Scrape Creators returned 404: Not Found".** `getInstagramPost()` was the **only** Scrape Creators call still using `POST /v1/instagram/post` + JSON body; that endpoint is GET-only, so it 404'd every IG post fetch — across the task panel, account manual-post route, and the async `scrape-post` Trigger job. The account-feed fallback couldn't save them either (raw `/reel/…` URLs carry no handle; rows had `source_handle`/`social_account_id` null). Same bug class as a TikTok GET-migration fix the day before. Fix: GET `?url=` like every other call. Full gotcha: [[scrape-creators-get-endpoints]]. Server-side → needs an app deploy **and** a `trigger deploy`; already-failed rows re-scrape only after a **Refresh**.

## Incidents distilled (2026-07-01)

- **"Scrape & find voice" keeps yielding no clean clip → links a library voice.** Not the scraper and not the isolation models (RunPod logs show Demucs/DeepFilterNet3/pyannote/Whisper all loading and finishing cleanly on 6–15 s clips; the red lines are infra cold-start noise). The bottleneck is the **acceptance gate vs. the source**: `services/voice-isolation/pipeline.py` demands a continuous solo-speech window at high purity / near-zero overlap / low music residue, pointed at short, music-bedded, jump-cut TikToks. The **live RunPod endpoint env was already loosened** past the code defaults in a prior session (purity 0.97→0.92, window 8→5 s, SNR 12→9, overlap 0→0.2 s, music 0.06→0.10), so it still failing means the **source** is the limit — making a **YouTube long-form audio path (yt-dlp) the real lever**, and confirming `fal-ai/sam-audio` (a Demucs swap only) wouldn't help. Full map + gate table + rejection taxonomy: [[voice-scrape-isolation-pipeline]]. Two reusable lessons pulled out: [[deployed-env-overrides-code-defaults]] and [[instrument-before-tuning-a-gate]]. Change made (staging, uncommitted): an **always-on** `[scrape-character-voice] harvest complete {…rejected…}` diagnostic that fires on the library-fallback path where `harvest.rejected` was silently dropped, plus realigning `pipeline.py` defaults to the live env for truthfulness.

## Operational notes

- **Every dashboard route sits behind Supabase-auth middleware** — unauthenticated requests 302 → `/login`. An agent/preview with no Supabase session can confirm a new route *compiles and redirects*, but **cannot do a full visual render**; headless QA of authed pages needs a real session. Flag this as a verification boundary rather than claiming a page was visually confirmed.
- The deploy wrapper needs `set -a` before `source .env` so the loaded vars are **exported** to the child deploy script — without it `source .env` sets but doesn't export, and `trigger deploy` gets no key and fails.
- Iterative cloud-state diagnosis here is expensive — one such session ran ~$100. Inspect the actual Trigger dashboard / Railway state early instead of theorizing from symptoms.
