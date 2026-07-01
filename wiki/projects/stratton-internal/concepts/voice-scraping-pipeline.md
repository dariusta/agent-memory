---
title: >-
    Voice Scraping Pipeline (Scrape & Find Voice)
category: concepts
tags: [domain/ai, domain/infra, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    stratton-internal's "Scrape & find voice" feature: UI → /api/characters/voice → Trigger job → Scrape Creators discovery + RunPod GPU isolation → LLM rank/auto-select 3 candidates → operator feedback learning loop.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:21Z
updated: 2026-07-01T08:30:21Z
---

# Voice Scraping Pipeline (Scrape & Find Voice)

The **"Scrape & find voice"** feature finds a real social-media creator whose voice fits an AI character, isolates a clean speech clip, and stamps it on the character as its cloning reference. It is one of the voice paths in [[stratton-internal]] (alongside Fish Audio cloning and "Match from library").

## End-to-end flow

1. **UI** — `apps/web/app/components/creators/character-voice-button.tsx` (modal "Voice — {character.name}"). "Scrape & find voice" `POST`s `{ mode:'scrape', characterId, characterType, preferenceFeedback, rejectedHarvestedIds }` to `/api/characters/voice`, then `pollVoiceRun()` polls `GET /api/characters/voice?runId=…` every 4s. The component is **genome-only** — every POST hardcodes `characterType:'genome'`. ^[extracted]
2. **Route** — `apps/web/app/api/characters/voice/route.ts` builds the discovery profile: if the character has no gender, it runs **Gemini vision on the face** (`deriveScrapeTraitsFromFace`) to infer gender/age/ethnicity, then derives discovery queries via LLM (`deriveDiscoveryQueries`, with a keyword fallback) and enqueues the Trigger.dev task with an idempotency key (queries-hashed, 2m TTL). ^[extracted]
3. **Background job** — `trigger/jobs/scrape-character-voice.ts` (`scrapeCharacterVoice`). Calls `scrapeAndHarvestForKeyword` (in `packages/integrations/src/voice-scrape.ts`) which: searches TikTok via [[scrape-creators]], downloads candidate videos, and sends each to the **RunPod GPU voice-isolation worker** (Demucs stem-split / pyannote diarization / Whisper transcript). Clean clips get banked to the `harvested_voices` table. ^[extracted]
4. **Rank & pick** — `rankHarvestedVoices` (`packages/integrations/src/voice-match.ts`) orders candidates against the character profile with a per-candidate `%fit` confidence + rationale. `pickWithDemographicGate` enforces a **wrong-gender reject** before auto-selecting. Rank #1 is auto-stamped (`voice_mode:'automatic'`, `voice_sample_url`, `voice_reference_text`, `voice_harvested_id`); the top set is persisted to `voice_candidates` so the operator can switch without re-scraping. ^[extracted]
5. **Fallback** — if a run banks no fresh clip, it falls back to the existing library (`loadLibraryFallbackCandidates`) through the same demographic-gated picker. ^[extracted]

## Data model (migration 186)

- `harvested_voices` — the bank of isolated clips.
- `voice_candidates` (column on both `genome` + `ai_slop` character tables) — the top ranked options for a character so the 3-way chooser and switching are instant. ^[extracted]
- `voice_candidate_feedback` (table) — the learning ledger: every candidate shown, the auto-pick, the operator's action (`approved` / `overridden_to` / `rejected`), reason, the ranker's own confidence + rationale, and character traits. ^[extracted]

Migration `186_voice_candidate_learning.sql` was applied to **prod** (`qoobzhuqmfnkfzoytodd`, "Stratton dash") via the Supabase MCP recorded path and verified live (columns, table, RLS, 2 policies, 4 indexes). Remember: staging **shares the prod Supabase DB**, so this landed for both. Backend code was written to **degrade gracefully** if the column/table is absent (auto-select keeps working; the 3-way switch + learning stay inert). ^[extracted]

## The learning loop

`loadVoiceLessons` (`trigger/jobs/lib/character-voice-selection.ts`) aggregates past overrides/rejections — **this character first, then trait-similar characters** — and injects them into the ranker prompt as "learned corrections" so it stops repeating the same mis-picks. `POST { mode:'select' }` and `reject` both write the feedback signal. This is a reusable pattern captured separately in [[llm-ranker-feedback-learning-loop]]. ^[extracted]

## Speed: the "10 minutes" was cold starts, not GPU

The feature felt terribly slow (~10 min). Isolation itself is **<1s/clip** — the wall-clock was **RunPod serverless cold-starts × sequential isolation**. Fixed by (a) warming the endpoint (`idleTimeout 30→200s`, `maxWorkers 2→4`, min still 0 = no idle cost) so the worker survives between clips in a run, and (b) making isolation a **parallel worker pool** (4 concurrent) instead of sequential. Expect ~1–2 min. Full reusable lesson: [[runpod-serverless-cold-start-latency]]; the platform: [[runpod]]. ^[extracted]

Related: [[trigger-dev]] (the job runtime), [[scrape-creators]] (discovery), [[video-url-resolution]].
