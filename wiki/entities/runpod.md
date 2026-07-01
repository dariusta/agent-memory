---
title: >-
    RunPod
category: entities
tags: [domain/infra, domain/ai, tool/runpod, type/service, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Serverless GPU host for stratton-internal's ML workers (voice-isolation, comfy-realism, qc-inference, phone-relay); one endpoint per service, config split between live endpoint env vars and a pinned Docker image tag.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.68
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:02Z
updated: 2026-07-01T08:30:02Z
---

# RunPod

Serverless **GPU compute** host. In [[stratton-internal]] it runs the ML workers under `services/` — `voice-isolation`, `comfy-realism`, `qc-inference`, `phone-relay` — each as its own **serverless endpoint** invoked from Trigger jobs. ^[extracted]

## How it's wired

- **One endpoint per worker.** e.g. voice-isolation = endpoint `8oy0pq82h9m2tx`. A worker is a `handler.py` taking `job["input"]` (e.g. `{ audio_url, max_bytes }`) and returning JSON. ^[extracted]
- **Two config surfaces — keep them straight.** Live **env vars** on the endpoint (tuning knobs, tokens like gated-pyannote `HF_TOKEN`) change with no rebuild; the **worker code** runs from a **pinned Docker image tag** and only updates on a rebuild + push + repoint. This split is a recurring foot-gun — see [[runpod-serverless-env-vs-image]].
- **Images are large GPU/CUDA builds** (~10 GB), built with `build.sh` forcing `linux/amd64` (buildx emulates on Apple silicon) and pushed to Docker Hub. Too heavy to build inside a lightweight agent sandbox.
- **Managed via the RunPod MCP** — `get-endpoint` (with `includeTemplate:true` to see the image tag), `update-endpoint` (env map is replaced wholesale — re-send the full env), `run-endpoint`, `endpoint-health`, plus pod/template/registry tools.

## Related

- [[voice-isolation-pipeline]] — the best-documented RunPod worker; VoxCPM reference-clip cleaner.
- [[voice-scrape-isolation-pipeline]] — the acceptance-gate / yield view of that same worker.
- [[runpod-serverless-env-vs-image]] — env change is live, code change needs an image rebuild.
- [[deployed-env-overrides-code-defaults]] — the live endpoint env can silently differ from code defaults.
- [[runpod-serverless-cold-start-latency]] — slow interactive GPU features are usually cold starts, not compute (`idleTimeout` / `min`=0 / `max` levers).
- [[trigger-dev]] — the job platform whose tasks call these endpoints.
