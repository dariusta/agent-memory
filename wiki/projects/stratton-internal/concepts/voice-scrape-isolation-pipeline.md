---
title: >-
    Voice-Scrape Yield — Gate vs. Source Diagnosis
category: concepts
tags: [domain/ai, domain/audio, domain/infra, type/diagnosis, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Why "Scrape & find voice" keeps banking 0 clips and falling back to the library: not the scraper or models — the strict solo-speech gate (already loosened in prod) vs. hard TikTok source; the real lever is a YouTube long-form audio path.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.63
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:48Z
updated: 2026-07-01T08:29:48Z
---

# Voice-Scrape Yield — Gate vs. Source Diagnosis

Why does "Scrape & find voice" so often bank **0 fresh clips** and fall back to "linked a reusable library voice"? This page is the *yield diagnosis* — a companion to the mechanics in [[voice-scraping-pipeline]] (the end-to-end scrape→rank→pick flow) and [[voice-isolation-pipeline]] (the RunPod isolation worker internals). ^[inferred]

## It's neither the scraper nor the isolation models — it's the gate vs. the source

RunPod isolation logs are **healthy**: every worker loads Demucs + DeepFilterNet3 + pyannote + Whisper, transcribes at 0.96–1.00 language confidence, and prints `Finished.` on **6–15 s** clips. The red lines (`Job has missing field(s): id or input`, cold-start `TimeoutError`) are RunPod infra noise, not model failures. So the "no clean clip" verdict is made at the **acceptance gate**, not in the scraper or the models. ^[extracted]

The gate (`services/voice-isolation/pipeline.py`) accepts a window only if it clears **all** thresholds — and each is read from **env at import time** (`os.getenv("VI_…", <default>)`); the client sends only `audio_url`, so there are **no per-job overrides** (the live endpoint env is the real gate — see [[deployed-env-overrides-code-defaults]]):

| Threshold (env var) | `pipeline.py` default | **Live endpoint env** |
|---|---|---|
| Speaker purity (`VI_MIN_SPEAKER_PURITY`) | 0.97 | **0.92** |
| Max other-speaker sec (`VI_MAX_OTHER_SPEAKER_SEC`) | 0.0 | **0.2** |
| Min solo-window sec (`VI_MIN_WINDOW_SEC`) | 8 | **5** |
| Min SNR dB (`VI_MIN_SNR_DB`) | 12 | **9** |
| Max music residue (`VI_MAX_MUSIC_RESIDUE`) | 0.06 | **0.10** |

## The gate was already loosened in prod → the source is the limit

The live endpoint (`8oy0pq82h9m2tx`) was **already relaxed** in a prior session, well past the code defaults. Since it **still** yields 0 clips at that relaxed bar, further loosening would be a blind guess that risks degrading clone timbre — so *don't*. The bottleneck is the **source**: short, music-bedded, jump-cut TikToks rarely contain an 8–15 s continuous single-speaker window. (Aligning the `pipeline.py` defaults to the live env was a *truthfulness-only* edit; env still overrides them — the deploy-side twin of this is [[runpod-serverless-env-vs-image]].) ^[inferred]

- **YouTube is the real lever.** A 5–10 min talking-head/vlog/podcast hands the *same* isolation stack dozens of clean solo windows vs. one music-bedded 30 s TikTok. Needs a **yt-dlp audio-download path** — today only `getYouTubeProfile` exists (profile metadata), no audio pull; see [[scrape-creators]]. ^[inferred]
- **`fal-ai/sam-audio` is NOT the answer.** It only replaces the Demucs separation step, which already works — it wouldn't raise clean-clip yield. ^[inferred]

## Prove it with a number: the rejection-reason distribution

Don't argue gate-vs-source — measure it (the [[instrument-before-tuning-a-gate]] pattern). The pipeline emits precise per-window reasons aggregated into `harvest.rejected` (`Record<reason, count>`): `input_too_short`, `multi_speaker_no_solo_window`, `windows_failed_quality_gate`, `budget_exhausted`, `isolation_timeout`.

**The diagnostic gap:** on the exact path the user hits (banked === 0 → library fallback succeeds, `trigger/jobs/scrape-character-voice.ts` ~468–499) that map was **silently dropped**. Fix applied (2026-07-01, `staging`, uncommitted): an **always-on** diagnostic on every terminal path including the fallback-success one —

```
[scrape-character-voice] harvest complete {"attempted":…,"banked":…,"rejected":{…},"fatalError":…}
```

Reading it after one real run decides the next build: dominated by `input_too_short` / `multi_speaker_no_solo_window` / `windows_failed_quality_gate` → **source** → build the YouTube path; dominated by `budget_exhausted` / `isolation_timeout` or `attempted: 0` → **discovery/budget** (query expansion or a bigger harvest budget), and YouTube won't help.

Part of [[stratton-internal]]. Siblings: [[voice-scraping-pipeline]], [[voice-isolation-pipeline]], [[runpod-serverless-cold-start-latency]].
