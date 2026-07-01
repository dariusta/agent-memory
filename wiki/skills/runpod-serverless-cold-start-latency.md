---
title: >-
    RunPod Serverless: Slow Interactive Feature = Cold Starts, Not Compute
category: skills
tags: [domain/infra, domain/ai, type/gotcha, type/howto, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    When a serverless-GPU feature takes minutes but the actual compute is sub-second, the cost is cold-starts × sequential calls — fix with idleTimeout warm-window, a parallel worker pool, and baking model weights into the image.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.58
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:21Z
updated: 2026-07-01T08:30:21Z
---

# RunPod Serverless: Slow Interactive Feature = Cold Starts, Not Compute

**Symptom:** an interactive feature backed by a serverless GPU endpoint takes minutes (e.g. ~10), and the instinct is "the model/GPU is slow." **Measure first** — often the actual inference is **sub-second** (a Demucs voice-isolation clip is <1s) and the wall-clock is entirely **cold starts × sequential invocations**. ^[extracted]

## How to confirm it's cold starts

Read the *worker* logs, not just the client. The tells:

- Repeated **model-load / weight-download** lines between jobs (e.g. an 80 MB Demucs checkpoint `…​.th` re-downloading on every boot). ^[extracted]
- Each job finishes faster than the endpoint's `idleTimeout`, so the worker **dies between jobs and re-boots** for the next one. If you fire N clips sequentially you pay the full cold start (~15–40s of model load) N times. ^[inferred]
- Queue-poll noise like `Failed to get job | missing field(s): id or input` / `TimeoutError` is usually harmless RunPod polling, not the latency source. ^[extracted]

## The levers (RunPod serverless endpoint config)

- **`idleTimeout`** — how long a worker stays alive after a job. Raise it to **span a whole multi-call run** (e.g. 30→200s) so the worker survives between calls instead of cold-starting each one. This is the single biggest lever. ^[extracted]
- **`min` workers = 0** — keep it at 0 and there is **no idle cost**: workers only exist while busy or inside the `idleTimeout` window. So a longer `idleTimeout` with `min=0` costs nothing when the feature is truly idle. ^[extracted]
- **`max` workers** — the concurrency ceiling. Raise it (e.g. 2→4) so a **parallel client pool** can actually spin up that many workers at once. ^[extracted]
- **Bake model weights into the image, or mount a network volume** — otherwise the checkpoint re-downloads on every cold boot. (Lower priority once cold-start frequency is fixed; a ~1s download is noise next to a 20s+ model load.) ^[inferred]
- **FlashBoot** helps snapshot the worker but does **not** eliminate the model-load cost — don't rely on it alone. ^[inferred]

## Client side

**Parallelize the calls** — a worker pool of N concurrent requests instead of a sequential loop. Combined with a warm-window `idleTimeout` and a high enough `max`, N calls hit warm workers in roughly **one batch** rather than N serial cold-starts. ^[extracted]

## Meta-lesson

Before optimizing the model or GPU, find where the wall-clock actually goes. For interactive serverless-GPU work the bottleneck is usually **orchestration (cold starts, sequential fan-out)**, not the kernel. The config change can be applied **live** to the endpoint with zero code deploy.

First surfaced building [[stratton-internal]]'s [[voice-scraping-pipeline]]; platform notes in [[runpod]].
