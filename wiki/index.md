---
title: >-
    Wiki Index
category: meta
summary: >-
    Master index of every page in this knowledge wiki, grouped by category. Updated by wiki-update / wiki-capture on every sync.
updated: 2026-06-29T02:19:37Z
---

# Wiki Index

Compiled knowledge distilled from projects and conversations. This index lists every page by category so retrieval can filter cheaply before reading any page body.

## Categories

- **concepts/** — general ideas, architectures, mental models
- **entities/** — tools, services, people, organizations
- **skills/** — reusable patterns, techniques, how-tos
- **references/** — source summaries and external material
- **synthesis/** — cross-project analysis and connections
- **projects/** — project-specific knowledge (`projects/<name>/<name>.md` is each project's anchor)
- **journal/** — dated notes and running logs

## Pages

### concepts

_(none yet)_

### entities

- [[trigger-dev]] — background-job platform; env chosen by `TRIGGER_SECRET_KEY` prefix, code changes need a worker redeploy.

### skills

- [[trigger-dev-environment-routing]] — "TTL (10m) expired" = job routed to the dev env (no persistent worker); diagnose by env/key, don't reach for a `ttl` knob.
- [[ffmpeg-filter-version-compatibility]] — version-gated filter options (e.g. `curves interp=pchip`, ffmpeg 5.1+) fail the whole graph on older binaries; validate against the prod ffmpeg.

### references

_(none yet)_

### synthesis

_(none yet)_

### projects

- [[stratton-internal]] — Next.js 15 / Railway app generating AI UGC video ads; Trigger.dev background jobs; staging shares the prod Supabase DB.

### journal

_(none yet)_
