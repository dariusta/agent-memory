---
title: >-
    Video URL Resolution (stratton-internal)
category: concepts
tags: [domain/web, domain/media, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    A produced video usually lives in the video_assets table, not video_tasks.final_video_url; resolve any task's playable cut through the canonical apps/web/lib/final-video.ts, never a single column.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.72
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-07-01T00:24:10Z
updated: 2026-07-01T00:24:10Z
---

# Video URL Resolution (stratton-internal)

Any surface that displays "the video for a task" (editor, campaign drawer, public `/share/<token>` page, the Gallery) must resolve the playable URL through the **canonical helper `apps/web/lib/final-video.ts`** — not by reading one column. Reusing it means every surface plays the same cut the team/client reviewed.

## The data-model gotcha (the whole point)

`video_tasks.final_video_url` is **not** a reliable "a video was made" signal. It's only set for a canvas Output node or a successful render. Most produced videos actually live in the **`video_assets`** table (`video_task_id` FK, `asset_type` default `raw_upload`; observed types: `deliverable`, `rendered`, `ai_generated`, `render_failed`, `raw_upload`), stored either as a public `url` **or** a private `storage_path` that must be signed to be playable. ^[extracted]

Consequence: a list built by querying only `video_tasks.final_video_url` **silently drops most videos** — this was the actual bug in the first Gallery cut. To enumerate *all* videos, resolve every task through `final-video.ts`; only truly video-less tasks should be omitted. ^[extracted]

## Canonical resolution order

Most-authoritative first (mirrors the campaign drawer's `pickReviewedVideoUrl`):

1. `video_tasks.final_video_url` (trimmed) if present.
2. Otherwise a `video_assets` row, by `asset_type` preference `['deliverable', 'final_render', 'approved', 'rendered', 'edit']`, **newest-first within each type** (a later revision wins); then any remaining video asset newest-first as a last resort. A row counts as video if `mime_type` starts with `video/` or the `url` ends `.mp4/.mov/.webm/.m4v`.
3. For the chosen row: return its public `url`; else sign its private `storage_path` against the **`video-assets`** public bucket with a **7-day TTL**.

## Two entry points

- `resolveFinalVideoUrl(taskId)` — single task; signs one storage path inline. Used by the public share page and other server callers.
- `resolveFinalVideoUrls(taskIds)` — **batch** variant added for list surfaces (the Gallery). N+1-free: one `video_tasks` query, one `video_assets` query for all ids, one `createSignedUrls` batch call. Returns a `Map<taskId, url>`, omitting tasks with nothing playable. Both share the same preference walk (`pickAssetForTask`). ^[extracted]

The lesson generalizes: when a list surface needs a per-row derivation the app already does one-at-a-time, add a **batch resolver next to the canonical single-item one** (reusing its constants and order) rather than duplicating the logic or firing N queries.

## Related

- The **Gallery** page (`apps/web/app/(dashboard)/gallery/page.tsx`, nav "Other" section) is the first consumer of the batch resolver — it scans up to 1000 tasks newest-first and shows every one with a resolvable video.
- All `/gallery` (and other dashboard) routes sit behind Supabase-auth middleware — see the auth-gated-preview note in [[stratton-internal]]. An agent with no Supabase session can only confirm the route compiles/redirects to `/login`, not do a full visual render.
- Route access is registered in `packages/auth/src/routes.ts` (`ROLE_ROUTE_PREFIXES` / `canAccessPath`, per internal-role surface).
