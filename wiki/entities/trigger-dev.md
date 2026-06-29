---
title: >-
    Trigger.dev
category: entities
tags: [domain/infra, domain/tooling, type/reference, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    Background-job / task orchestration platform; jobs route to dev/staging/prod environments by the TRIGGER_SECRET_KEY prefix, and code changes require a worker redeploy.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.72
lifecycle: draft
lifecycle_changed: 2026-06-29
created: 2026-06-29T02:19:37Z
updated: 2026-06-29T02:19:37Z
---

# Trigger.dev

Background-job / durable-task orchestration platform. Tasks are defined with `task()` (options like `maxDuration`, `concurrencyLimit`, `ttl`) and enqueued with `tasks.trigger()`.

## Facts learned in use (SDK v4.4.6)

- **Environments:** `dev`, plus deployed envs (staging/prod). The target env is chosen by the **`TRIGGER_SECRET_KEY` prefix** (`tr_dev_…` vs `tr_prod_…`) on the calling client when no explicit `configure()` is passed.
- **Dev env has a built-in default 10-minute queue-TTL**; deployed envs do not. The dev env only executes runs while a `npx trigger dev` tunnel is connected. This is the root of the "Run expired because the TTL (10m) was reached" failure — see [[trigger-dev-environment-routing]].
- **Deploying:** `npx trigger deploy` (add `--env staging` for a staging worker). Code changes to a task only take effect after a worker redeploy; the live worker can be weeks stale. The deploy builds a container (slow if it bundles ffmpeg/Remotion).
- `ttl` is a valid option both at trigger time (per-run) and on the `task()` definition (task-level default) — but per-run / dev defaults take precedence, so a task-level `ttl` can't override the dev 10m default.
- A run that expires shows `Duration: 0ms` and a `PARTIAL`/expired status in the dashboard — it never started.

Used by [[stratton-internal]].
