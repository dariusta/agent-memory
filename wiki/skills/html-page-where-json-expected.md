---
title: >-
    An HTML page where JSON was expected = the request hit the wrong route
category: skills
tags: [domain/web, type/debugging, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    A fetch that returns the framework's HTML 404/error page instead of JSON means the URL matched no route — usually a base-path / mount-prefix mismatch after an app is folded under a sub-path.
provenance:
  extracted: 0.5
  inferred: 0.45
  ambiguous: 0.05
base_confidence: 0.6
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T06:03:38Z
updated: 2026-07-02T06:03:38Z
---

# An HTML page where JSON was expected = the request hit the wrong route

**Symptom:** a client fetch that expects JSON fails with a parse error, or a
UI shows a generic "failed to load X" — and when you look at the actual
response body it's a chunk of **`<!DOCTYPE html>…`** (the framework's 404 /
not-found / error page), not an API payload.

**What it means:** the request URL **matched no API route**, so the framework's
catch-all page renderer answered instead of your handler. It is almost never a
bug in the handler — the request never reached it. Don't debug the endpoint;
debug the **path**.

## The usual cause: a base-path / mount-prefix mismatch

The highest-probability root cause is that an app (or its API client) was
**moved or folded under a path prefix**, but the client's base URL wasn't
updated to match. The client fetches `/api/<path>` while every route now lives
at `/api/<prefix>/<path>`, so each call lands on the catch-all.

Concrete case — [[stratton-internal]] ecom (2026-07-02): the `/ecom` surface was
folded into the shared `apps/web` Next.js app and its routes moved under
`app/api/ecom/*`, but the ecom API client (`ecom/lib/api.ts`) still fetched
`/api${path}`. Every panel call ("Failed to load connections") got Next's 404
**HTML** page back. Fix: the client **normalizes every call onto the `/api/ecom`
mount** (both bare paths and `/ecom/...` paths), and a **sweep of all ~30
`api.*` call sites** confirmed each resolves to a real route (including
dynamic-segment ones). ^[extracted]

## Debugging heuristic

- **Look at the raw response body, not just the thrown error.** `<!DOCTYPE html>`
  / a `<title>Page not found</title>` where you expected JSON is the tell.
- Check the response **status + `content-type`**: an HTML `text/html` 404 (or a
  200 serving an SPA shell) means routing, not logic.
- Ask **"did this app recently move under a sub-path / get mounted behind a
  prefix / change its router basePath?"** — if yes, audit the client base URL
  first.
- **Sweep every call site** of the client, not just the one that broke — a
  base-path bug hits all of them; the one you noticed is arbitrary. Include
  dynamic-segment routes.
- Same failure class shows up behind reverse proxies (a `location` prefix not
  stripped/added), SPA history fallbacks (unknown path → `index.html`), and
  trailing-slash redirects.

Sibling gotcha in the same repo: a merged fix that never reached the deployed
worker can produce an identical-looking persistent 4xx — tell them apart by the
response body. See [[scrape-creators-get-endpoints]].
