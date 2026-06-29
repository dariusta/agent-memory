---
title: >-
    Hot — Working Memory
category: meta
summary: >-
    Fast-context scratchpad read first by wiki-query: recent activity, active threads, and key takeaways. Rewritten on every sync.
updated: 2026-06-29T02:19:37Z
---

# Hot — Working Memory

The first thing `wiki-query` reads. Keep it short and current.

## Recent Activity

- [2026-06-29] Synced **[[stratton-internal]]** (first sync) — Next.js 15 / Railway app for AI UGC video ads on Trigger.dev. Distilled two debugging incidents into reusable skills.
- [2026-06-28] Wiki initialized — scaffolded vault structure, config, and index.

## Active Threads

- **stratton-internal infra** — staging was routing Trigger.dev jobs to the dead `dev` env; fixed by repointing staging's `TRIGGER_SECRET_KEY` to prod and redeploying the worker (`v20260629.1`). Staging and prod now share the same Trigger worker/queue (as they already share the prod Supabase DB).

## Key Takeaways

- **Trigger.dev "TTL (10m) expired" = a job routed to the `dev` environment**, which has no persistent worker. The env is chosen by the `TRIGGER_SECRET_KEY` prefix; the tell vs a concurrency backlog is *every* run expiring at 0ms. Don't reach for a `ttl` knob — fix the key/env. → [[trigger-dev-environment-routing]]
- **FFmpeg filter options are version-gated** — an option missing from the prod binary (e.g. `curves interp=pchip`, ffmpeg 5.1+) fails the *whole* graph; a "skipped" fallback then hides a 100%-failure regression. Validate chains against the deploy ffmpeg, not your newer local one. → [[ffmpeg-filter-version-compatibility]]
- **Inspect real cloud state early.** Both incidents were diagnosed faster by reading the Trigger dashboard / Railway env vars than by theorizing from symptoms; the iterative-guessing session ran ~$100.
