---
title: >-
    Scrape Creators API: all post-fetch endpoints are GET ?url= (POST+JSON 404s)
category: skills
tags: [domain/integration, domain/tooling, type/howto, type/gotcha, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    A bare "Scrape Creators returned 404: Not Found" usually means a call hit a GET-only endpoint with POST + JSON body; every working call uses GET with a ?url= query param.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T00:57:44Z
updated: 2026-06-30T00:57:44Z
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

- The stored error is the literal `Scrape Creators returned 404: Not Found` with no body. A genuine coverage gap or a bad URL tends to return a JSON error or a different status. ^[inferred]
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

See [[scrape-creators]] and the project context in [[stratton-internal]].
