---
title: >-
    Trigger.dev environment routing & the dev 10-minute queue-TTL
category: skills
tags: [domain/infra, domain/tooling, type/howto, type/decision, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    "Run expired because the TTL (10m) was reached" means a job was routed to Trigger.dev's dev env (no persistent worker); the env is chosen by the TRIGGER_SECRET_KEY prefix.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.68
lifecycle: draft
lifecycle_changed: 2026-06-29
created: 2026-06-29T02:19:37Z
updated: 2026-06-29T02:19:37Z
---

# Trigger.dev environment routing & the dev 10-minute queue-TTL

## The symptom

A background run dies with **"Run expired because the TTL (10m) was reached."** In the dashboard the run shows `Duration: 0ms`, status `PARTIAL`, environment `dev` — it **never started executing**, it sat queued for 10 minutes and expired.

## What's actually happening

- **Only the `dev` environment has a built-in default 10-minute queue-TTL.** Docs: *"All runs in development have a default `ttl` of 10 minutes. You can disable this by setting the `ttl` option."* Deployed environments (staging/prod) have **no** such default. So the literal "10m" is a fingerprint that the run was routed to **dev**. ^[extracted]
- **The `dev` env's only worker is a laptop running `npx trigger dev` (tunnel mode).** With no tunnel connected, runs queue and die at the 10m TTL — they can never execute there. ^[extracted]
- **Which environment a job lands in is decided entirely by the `TRIGGER_SECRET_KEY` prefix** when you call `tasks.trigger()` with no explicit `configure()`: `tr_dev_…` → dev, `tr_prod_…` → prod. So a deployed app accidentally holding a `tr_dev_…` key sends *every* background job to the dead dev env. ^[extracted]

## The diagnostic tell

If it were a concurrency/queue-backlog problem (`concurrencyLimit` + long `maxDuration`), **some** runs would eventually complete. If **every** run expires at exactly +10m with 0ms duration, it is not backlog — it's dev-environment routing with no connected worker. Check the environment column on the runs, and check `TRIGGER_SECRET_KEY` on each deployment (prod vs staging may differ). ^[inferred]

## The fix (config, not code)

Point the offending deployment at an environment that has a **persistent deployed worker**:

- **Option A (least effort):** set its `TRIGGER_SECRET_KEY` to the prod key so it enqueues into the prod env. Sensible when that deployment already shares prod resources (e.g. the same Supabase DB).
- **Option B (cleaner isolation):** give it a Trigger *staging*-env key and run `npx trigger deploy --env staging` to stand up a dedicated worker.

Either way, **redeploy the worker** with current task code (`cd trigger && npx trigger deploy`) — a code change to a task does not reach already-running workers, and the live worker can be weeks stale.

## The false start to avoid

Adding a **task-level `ttl`** (e.g. `ttl: '1h'`) does **not** fix this:
- It cannot override the per-run dev default (applied at trigger time, higher precedence), so the run still expires.
- In a real deployed env (which has no default TTL) it *introduces* an expiry that wasn't there before — strictly worse.

Diagnose the actual environment/key first; don't reach for a TTL knob. ^[inferred]

See [[trigger-dev]] and the project context in [[stratton-internal]].
