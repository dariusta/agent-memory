---
title: >-
    Scrape Creators
category: entities
tags: [domain/integration, domain/tooling, type/reference, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    Third-party API for scraping social posts/accounts (Instagram, TikTok); single-item fetch endpoints are GET ?url=, and a POST to one returns a bare 404.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.68
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T00:57:44Z
updated: 2026-06-30T00:57:44Z
---

# Scrape Creators

Third-party HTTP API that scrapes social-media posts and accounts (Instagram, TikTok, …). In stratton-internal it powers post/account tracking, voice scraping, and the "Mark posted → scrape" flow, wrapped in `packages/integrations/src/scrape-creators.ts`.

## Facts learned in use

- **Single-item fetch endpoints are GET with a `?url=` query param**, e.g. `GET /v1/instagram/post?url=…`, `GET /v1/tiktok/post?url=…`. There is no JSON-body POST variant — calling one with POST + a body returns a plain **`404: Not Found`** (no error JSON). See the gotcha in [[scrape-creators-get-endpoints]]. ^[extracted]
- The same `/v1/instagram/post` endpoint backs both a "post details" fetch (`getInstagramPost`) and a "post video" fetch (`getPostVideo`) — both are GET. ^[extracted]
- Account/feed scrapes need a **handle**; a raw `/reel/…` or `/p/…` URL carries none, so a feed-based fallback can't resolve a bare post URL. ^[extracted]
- Auth is a server-side API key, so any fix to the client is server-side and **needs a deploy** to take effect (and a separate `trigger deploy` for the Trigger.dev job that calls it). ^[inferred]
- **Voice harvesting is TikTok-only.** `searchTikTokKeyword()` hits `/v1/tiktok/search/keyword` (deduped by aweme id) for discovery, and `getPostVideo()` downloads via `/v2/tiktok/video?url=…&download_media=true` (a **permanent stored** URL, not CDN-ephemeral). There is **no YouTube audio-download path** — only `getYouTubeProfile` (profile metadata). See [[voice-scrape-isolation-pipeline]]. ^[extracted]

Used by [[stratton-internal]].
