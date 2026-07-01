---
title: >-
    Scrape Creators API: all post-fetch endpoints are GET ?url= (POST+JSON 404s)
category: skills
tags: [domain/integration, domain/tooling, type/howto, type/gotcha, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    A bare "Scrape Creators returned 404: Not Found" usually means a call hit a GET-only endpoint with POST + JSON body; every working call uses GET with a ?url= query param.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.74
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T00:57:44Z
updated: 2026-07-01T08:30:00Z
---

# Scrape Creators API: all post-fetch endpoints are GET ?url= (POST+JSON 404s)

## The symptom

A scrape fails with a bare **`Scrape Creators returned 404: Not Found`** — no JSON error body, just a 404. The post and the account are fine; the request shape is wrong. ^[extracted]

## What's actually happening

Scrape Creators' single-item fetch endpoints (`/v1/instagram/post`, `/v1/tiktok/post`, post-video, account feeds) are **GET with a `?url=` query param**. Calling one with **POST + a JSON body** returns a plain `404: Not Found` (the path effectively doesn't exist for that method), which is easy to misread as "this post isn't covered." ^[extracted]

In stratton-internal this bit `getInstagramPost()` in `packages/integrations/src/scrape-creators.ts` — the **only** Scrape Creators call still using `POST /v1/instagram/post` with a JSON body. Every other call had already been migrated to GET:

- `getTikTokPost` → GET `?url=` ✅
- `getInstagramPosts` (account feed) → GET `?url=` ✅
- `getPostVideo` → GET `?url=` ✅ — and it hits the **same** `/v1/instagram/post` endpoint, with a comment "Both post endpoints are GET"

So a sibling function was already calling the exact endpoint correctly; `getInstagramPost` was simply never migrated. ^[extracted]

## The diagnostic tell

- **The 404 body tells you *which* 404 it is** (confirmed empirically against the live API with a real key): a genuine missing/deleted post returns a JSON body `{"success":false,…,"message":"Post not found"}`, whereas a **wrong-method / wrong-path** 404 returns plain-text **`Not Found`** with no JSON. So a stored `Scrape Creators returned 404: Not Found` (plain text) is a wrong-method/gateway 404, **not** a coverage gap. ^[extracted]
- **Prove the posts are fine before touching them:** re-fetch one "failed" URL with `GET /v1/instagram/post?url=…` and the prod key. If it returns **200 with full data**, the account isn't banned and the post isn't deleted — the request shape (or the *deployed* code) is wrong. In this incident three "404'd" reels (`DaMcndKga-R`, `DaLsNdaCctx`, `DaLQLdKjaVA`) all returned 200 live. ^[extracted]
- **Grep the integration for the odd one out:** if every call uses GET `?url=` and one uses POST + JSON, the POST one is the bug. Don't theorize about the vendor — diff your own callsites against each other. ^[inferred]
- Confirm against the vendor docs (the IG-post endpoint is documented as `GET /v1/instagram/post?url=…`) and, if you store scrape errors, read the actual prod DB rows. ^[extracted]

## The fix

Make the function GET `?url=<normalized url>` like every other working call:

`GET /v1/instagram/post?url=<normalizeInstagramUrl(url)>`

Tests live at `packages/integrations/.../scrape-creators-instagram-post.test.ts`; when the URL moves into the query string, mock matchers must switch from exact-match to `includes` and a direct-GET happy-path is worth adding.

## Blast radius & deploy note

This integration is server-side, so a fix needs a deploy before it works live — and the Trigger.dev job needs its own `trigger deploy`. In stratton-internal, every IG "Mark posted" path funnels through `getInstagramPost`:

- the task panel route (`apps/web/app/api/tracking/posts/route.ts`),
- the account-page manual-post route (`apps/web/app/api/phone-farm/accounts/[id]/manual-post/route.ts`),
- the async `scrape-post` Trigger job (`trigger/jobs/scrape-post.ts`).

So one wrong HTTP method 404'd all three. The account-feed **fallback** couldn't save these either: it needs a handle, but a raw `/reel/…` URL carries none and the failed rows had `source_handle: null` / `social_account_id: null`. Already-failed rows keep their `scrape_error` until you hit **Refresh** to re-run the now-correct scrape. ^[extracted]

## Why this recurs

This was the **same bug class** as a TikTok post-fetch 404 fixed the day before (2026-06-28) — a migration to GET `?url=` that swept most callsites but left one POST+JSON function behind. When you migrate a vendor client's call convention, grep for *every* callsite of the old shape; a "skipped"/error-swallowing fallback can hide the stragglers for a long time. ^[inferred]

## The second way it recurs: the fix is merged but not deployed

The identical `Scrape Creators returned 404: Not Found` reappeared a day later even though the code was already GET-correct. The scrape runs inside the **Trigger.dev `scrape-post` worker**, which executes whatever code was frozen at its last `trigger deploy`. The GET fix — commit `37444c6c2` *"fix IG post endpoint to GET"* (`method: 'POST'` → `GET ?url=`), landed **2026-06-30 01:20 UTC** — was merged, but the live prod worker was **`v20260629.1`, deployed 2026-06-29 02:15 UTC — ~23 h *before* the fix**, so it still POSTed and 404'd every IG scrape. ^[extracted]

Diagnostic: when a fix is merged but the symptom persists, **compare the deployed Trigger.dev worker's version/date against the fix commit's date**. A plain web-app redeploy does **not** update the worker. Remedy is a worker deploy (`source .env && ./trigger/deploy.sh`), not a code change; already-failed rows re-scrape on the next **Refresh**. See [[trigger-dev]]. ^[extracted]

See [[scrape-creators]] and the project context in [[stratton-internal]].
