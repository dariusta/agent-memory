---
title: >-
    Voice-Isolation Pipeline (stratton-internal)
category: concepts
tags: [domain/media, domain/ai, domain/infra, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    RunPod GPU worker turning scraped UGC into one clean single-speaker clip for VoxCPM cloning; it was deliberately tuned to KEEP background noise for "iPhone authenticity", so full denoise is off by default and the common path outputs raw audio.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:02Z
updated: 2026-07-01T08:30:02Z
---

# Voice-Isolation Pipeline (stratton-internal)

`services/voice-isolation/` is a **RunPod serverless GPU worker** (endpoint `8oy0pq82h9m2tx`) that turns a messy scraped UGC clip (TikTok / Instagram) into **one clean single-speaker reference sample** for **VoxCPM** voice cloning. It's the back half of the character **voice-scrape** flow: scrape real creators matching a character → isolate the cleanest clip → save to the voice library. Called from the Trigger job `trigger/jobs/isolate-character-voice.ts` via `isolateVoice()` in `@stratton/integrations` (TS wrapper `packages/integrations/src/voice-isolation.ts`; the Python pipeline is `services/voice-isolation/pipeline.py` + `handler.py`). See [[runpod]], [[stratton-internal]].

> **Sibling page:** [[voice-scrape-isolation-pipeline]] covers the *front* of this feature — TikTok discovery, download, and the strict **acceptance gate / yield** problem (why a scrape returns *zero* clips). **This page covers the other half: how the one clip you do get is (or isn't) cleaned**, and the deliberate noise-vs-authenticity tradeoff behind it.

## Pipeline stages (order matters)

```
audio bytes
  → ffmpeg            decode to 16 kHz mono wav
  → Demucs (htdemucs) separate music/SFX from the vocal stem
  → DeepFilterNet     denoise + dereverb
  → pyannote          diarization (who speaks when)
  → Silero VAD        precise speech-vs-silence
  → strict window scoring → pick one clean single-speaker window
  → (Whisper transcript)
```

Window selection is gated by tunables (see below): min SNR, speaker purity, max other-speaker seconds, min/max window length, max music residue. ^[extracted]

## The key insight: Demucs DETECTS, it doesn't always CLEAN

The subtle part is **which audio actually goes into the output clip**. Demucs is run mainly to *locate* the best window; whether that window is cleaned depends on the path:

- **Raw-passthrough path (the common case — talking-to-camera, little/no music):** if `music_residue ≤ VI_RAW_PASSTHROUGH_MAX_RESIDUE` (default `0.02`), the worker outputs the **raw original audio** for the chosen window — most authentic, no separation artifacts, natural room tone. **All ambient noise (AC hum, street, room tone) stays in.** ^[extracted]
- **Separated path (music present):** it outputs the Demucs vocal stem for the window. Historically DeepFilterNet enhancement was **off by default** (`VI_ENHANCE_MODE=off`), so broadband background noise in the vocal band still survived. ^[extracted]

So "background noise survives voice isolation" was **not a bug** — it was deliberate.

## The deliberate noise/authenticity tradeoff

The pipeline was tuned to **preserve** the "recorded on an iPhone" character, because full studio denoise makes the *cloned* voice sound like a "podcast booth" and lose the UGC feel VoxCPM is meant to reproduce. `VI_ENHANCE_MODE` has three levels: `off` (keep iPhone character), `light` (50/50 dry-wet denoise), `full` (studio denoise). ^[extracted]

The lesson generalizes: **for voice cloning, the reference's noise floor is a product decision, not just a quality metric** — a "cleaner" reference can produce a *worse* (less natural) clone. Expose it as a dial, don't hardcode "cleanest".

## Enhance/output env vars

The **acceptance-gate** thresholds (`VI_MIN_SPEAKER_PURITY`, `VI_MAX_OTHER_SPEAKER_SEC`, `VI_MIN_WINDOW_SEC`, `VI_MIN_SNR_DB`, `VI_MAX_MUSIC_RESIDUE`) and their code-default-vs-live-endpoint drift are tabulated in [[voice-scrape-isolation-pipeline]]. The knobs that govern **output cleaning** (this page's focus) are:

- `VI_ENHANCE_MODE` — `off` | `light` (50/50 dry-wet) | `full` (studio denoise). Default flipped `off → full` on 2026-07-01.
- `VI_RAW_PASSTHROUGH_MAX_RESIDUE` (`0.02`) — below this music residue, output the raw window instead of the Demucs stem.
- plus `HF_TOKEN` (gated pyannote weights).

All live on the endpoint env and flip live via the RunPod API/MCP without a rebuild — but see the deploy caveat below. ^[extracted]

## 2026-07-01 change — full denoise ("just her voice")

Requirement: output must be **only the speaker's voice, no background**, overriding the authenticity tradeoff. Change:

- Routed the chosen output window through **DeepFilterNet in both paths** (raw *and* separated); refactored `enhance()` to denoise an arbitrary final clip and added a `raw_denoised` source. Flipped the default `VI_ENHANCE_MODE` `off → full`.
- Flipped the live endpoint env `VI_ENHANCE_MODE=off → full` (reversible).

**Gotcha that bit here:** the env flip alone only cleans the *music* path. The **raw-passthrough denoise is a code change**, so it doesn't go live until the ~10 GB CUDA image is rebuilt and the endpoint repointed — the endpoint still runs the pinned old image. Full reasoning: [[runpod-serverless-env-vs-image]]. Dial-back: set `VI_ENHANCE_MODE=light` if a clone ever sounds too booth-like (no rebuild needed).

## Related

- [[runpod-serverless-env-vs-image]] — why the code half of this fix needed an image rebuild, not just an env change.
- [[runpod]] — the GPU host; env-on-endpoint vs pinned image tag.
- [[stratton-internal]] — project overview; the voice-scrape flow that feeds this worker.
