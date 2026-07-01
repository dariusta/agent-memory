---
title: >-
    Deployed Env Can Silently Override Code Defaults
category: skills
tags: [domain/infra, domain/devops, type/gotcha, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    A running service's live env vars silently override git-tracked config defaults; verify the actual deployed config before tuning code, or you'll guess against a value that isn't running.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:48Z
updated: 2026-07-01T08:29:48Z
---

# Deployed Env Can Silently Override Code Defaults

When a service reads its config from environment variables at startup — e.g. `os.getenv("VI_MIN_SPEAKER_PURITY", 0.97)` read at **import time** — the number in the repo is only a *fallback*. The value that actually runs is whatever env the live deployment (RunPod endpoint, Railway service, container, Lambda) carries. **The repo can "lie" about the running behavior.** ^[extracted]

## Why it bites

- You read the code, see a strict default, and conclude "the gate is set to 0.97" — but the live endpoint is already at 0.92. Any tuning you do from the code number is a **blind guess against a value that isn't running**. ^[inferred]
- In stratton-internal this flipped a whole diagnosis: the voice-isolation gate looked strict in `pipeline.py` (0.97 / 8 s / 0 s overlap), but the live RunPod endpoint env had already been relaxed (0.92 / 5 s / 0.2 s) in a prior session. "Just loosen the gate" was **already done**, so the real bottleneck was elsewhere (the source). See [[voice-scrape-isolation-pipeline]]. ^[extracted]

## The rule

**Before tuning a config default, inspect the live deployment's actual env.** Pull the endpoint/service config (e.g. RunPod `get-endpoint`/`get-template` with `includeTemplate`, `railway variables`, `kubectl describe`) and compare it to the code defaults. Only then decide whether to change anything.

- If the client can't pass per-request overrides (it sends only the payload, not the knobs), the **live env is the single source of truth** — a code edit alone won't change runtime behavior until the image is rebuilt/redeployed without that env.
- When code defaults and live env have drifted, **realign the code defaults to the live values** as a truthfulness fix so the repo stops misrepresenting production — even though env still overrides them.

This is the config-layer twin of the broader stratton lesson: **inspect real cloud/dashboard state early instead of theorizing from symptoms** (see [[stratton-internal]] operational notes). Related diagnostic discipline: [[instrument-before-tuning-a-gate]].
