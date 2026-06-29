---
title: >-
    FFmpeg filter options are version-gated — validate against the prod binary
category: skills
tags: [domain/tooling, domain/infra, type/howto, type/decision, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    An unknown filter option (e.g. curves' interp=pchip, added in ffmpeg 5.1) fails the whole filter graph on older ffmpeg; validate chains against the deploy binary, not your newer local one.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-06-29
created: 2026-06-29T02:19:37Z
updated: 2026-06-29T02:19:37Z
---

# FFmpeg filter options are version-gated — validate against the prod binary

## The trap

An ffmpeg filter option that doesn't exist in the running binary is **fatal to the entire filter graph**, not silently ignored. The log looks like:

```
[Parsed_curves_3] Option 'interp' not found
Error initializing filter 'curves' with args 'interp=pchip:master=...'
Error reinitializing filters!
Failed to inject frame into filter network: Option not found
```

Concrete case: the `curves` filter's `interp` option was added in **ffmpeg 5.1**. Building `curves=interp=pchip:master=…` works locally on a newer ffmpeg but hard-fails on an older ffmpeg in the production/container image. The downstream code caught the error and fell through to "post-processing skipped," so the effect (a video de-AI/realism pass) **silently never ran on any output** — no crash, just missing behaviour. ^[extracted]

## Why validation missed it

The chains had been "validated" — but against a **newer local ffmpeg than production shipped**. Validating media pipelines on your dev machine's ffmpeg does not prove they run on the deploy image's ffmpeg. ^[inferred]

## Rules of thumb

- Treat ffmpeg filter args as **version-sensitive**; check the option's introduction version before using it, or pin/verify the container's ffmpeg version.
- Prefer **defaults over newer optional tuning args** when the default is good enough. Here, dropping `interp=pchip` and relying on `curves`' default natural cubic-spline interpolation kept the rolloff well-behaved for the three monotonic control points and made the filter work across all ffmpeg versions. ^[inferred]
- A "skipped / fell back" branch around a media step can hide a 100%-failure regression. Make such fallbacks loud (or assert the step actually ran) so a version gap surfaces immediately.
- Server-side filter-string changes aren't browser-observable, but a unit test often asserts the exact filter string — update it alongside the change.

Project context: [[stratton-internal]].
