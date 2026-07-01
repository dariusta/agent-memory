---
title: >-
    Voice-Scrape / Isolation Pipeline
category: concepts
tags: [domain/ai, domain/audio, domain/infra, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    stratton-internal's "Scrape & find voice" pipeline (TikTok harvest → RunPod isolation → strict acceptance gate); the yield bottleneck is the gate-vs-source, not the scraper or models.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:48Z
updated: 2026-07-01T08:29:48Z
---

# Voice-Scrape / Isolation Pipeline

The "Scrape & find voice" feature discovers real creators matching an AI character, harvests their audio, isolates a clean solo-speech clip, and banks it to a voice library for cloning. When a fresh scrape yields no accepted clip it **falls back to the best already-harvested library voice** — the "linked a reusable voice" outcome the user kept hitting. Orchestrated by `trigger/jobs/scrape-character-voice.ts`. Uses [[scrape-creators]] for discovery/download and a RunPod service for isolation.

## Stages

1. **Discovery — TikTok only.** `searchTikTokKeyword(query)` (`packages/integrations/src/scrape-creators.ts`) → Scrape Creators `/v1/tiktok/search/keyword`, deduped by aweme id. **YouTube and Instagram are profile-scraped elsewhere but are NOT voice-harvested.** ^[extracted]
2. **Query expansion.** `expandedScrapeQueries()` (`packages/integrations/src/voice-scrape.ts`) inflates each base niche into ~16 variants (`… talking to camera`, `… product review`, `… grwm`, `… morning routine`) so small niches don't exhaust. ^[extracted]
3. **Discovery filtering.** Drops verified (blue-check) and business accounts to favour organic UGC. ^[extracted]
4. **Download.** `getPostVideo(url)` → Scrape Creators `/v2/tiktok/video?url=…&download_media=true`, which returns a **permanent stored** download URL (not a CDN-ephemeral one). **No YouTube audio path exists** — only `getYouTubeProfile` (profile metadata). ^[extracted]
5. **Isolation (RunPod worker).** Loads **Demucs + DeepFilterNet3 + pyannote + Whisper**, separates music, diarizes, detects language (0.96–1.00 in healthy logs), and slices candidate solo-speech windows. Clips processed are typically **6–15 s**. ^[extracted]
6. **Acceptance gate** (see below) → banks accepted clips, or falls back to the library.

## The acceptance gate is the real story

`services/voice-isolation/pipeline.py` accepts a window only if it clears **all** thresholds. Each is read from **env at import time** (`os.getenv("VI_…", <default>)`), and the client sends only `audio_url` — there are **no per-job overrides**. So the *actual* gate is whatever env the live RunPod endpoint carries, which can silently differ from the git-tracked defaults — see [[deployed-env-overrides-code-defaults]].

| Threshold (env var) | `pipeline.py` default | **Live endpoint env (2026-07-01)** |
|---|---|---|
| Speaker purity (`VI_MIN_SPEAKER_PURITY`) | 0.97 | **0.92** |
| Max other-speaker sec (`VI_MAX_OTHER_SPEAKER_SEC`) | 0.0 | **0.2** |
| Min solo-window sec (`VI_MIN_WINDOW_SEC`) | 8 | **5** |
| Min SNR dB (`VI_MIN_SNR_DB`) | 12 | **9** |
| Max music residue (`VI_MAX_MUSIC_RESIDUE`) | 0.06 | **0.10** |

The live endpoint (`8oy0pq82h9m2tx`) was **already loosened** in a prior session — so "just loosen the gate" was largely already done. Editing `pipeline.py` defaults to match the live env was a *truthfulness* change only (env overrides them; it matters only if the endpoint is recreated without env). ^[extracted]

## Diagnosis: not the scraper, not the models — the gate vs. the source

Healthy isolation logs (every worker loads all models, transcribes, prints `Finished.`; the red lines are RunPod infra noise — `Job has missing field(s): id or input`, cold-start `TimeoutError`) prove the models work. Since it **still** yields 0 clips at the *relaxed* bar, the bottleneck is the **source**: short, music-bedded, jump-cut TikToks rarely contain an 8–15 s continuous single-speaker window. ^[inferred]

- **YouTube is the real lever.** A 5–10 min talking-head/vlog/podcast hands the *same* isolation stack dozens of clean solo windows vs. one music-bedded 30 s TikTok. Requires building a **yt-dlp audio-download path** (today there is none). ^[inferred]
- **`fal-ai/sam-audio` is NOT the answer.** It would only replace the Demucs separation step, which already works — it wouldn't raise clean-clip yield. ^[inferred]

## Rejection-reason taxonomy & the diagnostic gap

The pipeline emits precise per-window rejection reasons, aggregated into `harvest.rejected` as a `Record<reason, count>`:
`input_too_short`, `multi_speaker_no_solo_window`, `windows_failed_quality_gate`, `budget_exhausted`, `isolation_timeout`.

**The gap:** on the exact path the user hits (banked === 0 → library fallback succeeds, `scrape-character-voice.ts` ~468–499) that map was **silently dropped**, so you never saw *why* a scrape produced 0 clips. Fix applied (2026-07-01, staging, uncommitted): an **always-on** diagnostic that fires on every path including the fallback-success one:

```
[scrape-character-voice] harvest complete {"attempted":…,"banked":…,"rejected":{…},"fatalError":…}
```

This turns gate-vs-source into a number — the [[instrument-before-tuning-a-gate]] pattern. Reading it after one real run decides the next build: mostly `input_too_short` / `multi_speaker_no_solo_window` / `windows_failed_quality_gate` → **source** → build the YouTube path; mostly `budget_exhausted` / `isolation_timeout` or `attempted: 0` → **discovery/budget** (query expansion or bigger harvest budget), and YouTube won't help.

Part of [[stratton-internal]]. Related: [[scrape-creators]], [[trigger-dev]].
