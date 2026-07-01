---
title: >-
    RunPod Serverless — Env Change Is Live, Code Change Needs an Image Rebuild
category: skills
tags: [domain/infra, domain/ai, type/gotcha, tool/runpod, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    On a RunPod serverless endpoint, editing env vars takes effect instantly, but the endpoint runs a PINNED Docker image — a source change to the worker doesn't ship until you rebuild+push the image and repoint the endpoint.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:02Z
updated: 2026-07-01T08:30:02Z
---

# RunPod Serverless — Env Change Is Live, Code Change Needs an Image Rebuild

A RunPod serverless endpoint has **two independent update surfaces**, and it's easy to fix half a bug:

1. **Endpoint env vars** — change via the RunPod API / MCP (`get-endpoint` → `update-endpoint`) or the UI. Takes effect on the **next cold start, no rebuild**. Good for tuning knobs and feature flags the worker reads at runtime.
2. **Worker code** — runs from a **pinned Docker image tag** referenced by the endpoint's template. Editing the source in the repo does **nothing** to the live endpoint until you **rebuild + push the image and repoint the endpoint** at the new tag. ^[extracted]

## The failure mode

You change behavior that is *partly* env-gated and *partly* code, flip the env var, see it "work" for one path, and ship — but the code-only path still runs the old image. In stratton-internal's [[voice-isolation-pipeline]], flipping `VI_ENHANCE_MODE=off→full` denoised the *music* path immediately, but the *raw-passthrough* denoise was a new code branch, so talking-head clips stayed noisy until the image was rebuilt. The endpoint was still on `static1231/voice-isolation:merge-gap-ping-20260623`. ^[extracted]

## Checklist when changing a RunPod worker

- **Decide: is this change env-readable or code?** If the worker reads it from `os.getenv` at runtime → env flip is enough. If it's new logic → you need a new image.
- **Before claiming "it's live," check the endpoint's current image tag** (`get-endpoint includeTemplate:true`) against the tag you built. A stale tag = your code isn't running.
- **Preserve all other env vars on update.** `update-endpoint` env replaces the map — re-send the full existing env (incl. `HF_TOKEN` and every tunable), not just the one you changed. ^[inferred]
- **Big CUDA/ML images (~10 GB) can't be built in a lightweight agent sandbox** — no Docker daemon / registry creds. Hand the `build.sh` (force `linux/amd64` on Apple silicon; buildx emulates) to the human, get the pushed tag back, then repoint the endpoint via MCP. ^[extracted]
- **Env flips are reversible and cheap; image swaps are the real deploy.** Use env for dial-backs (e.g. drop an enhance level) without a rebuild.

## Why it's confusing

This mirrors the same class of bug as [[trigger-dev-environment-routing]] (config vs code) and [[scrape-creators-get-endpoints]] (one straggler call site): the *symptom* looks like a code bug, but a **deploy/plumbing seam** — here, env-surface vs image-surface — is where the fix actually has to land. Verify the runtime end-state (image tag), don't assume the source you edited is what's executing. See [[runpod]].
