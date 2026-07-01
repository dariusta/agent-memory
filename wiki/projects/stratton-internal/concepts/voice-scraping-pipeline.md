---
title: >-
    Voice Casting: 3-Candidate Chooser, Auto-Select & Learning Loop
category: concepts
tags: [domain/ai, type/architecture, type/decision, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    The selection layer on top of stratton-internal's voice-scrape/isolation pipeline: rank banked clips, auto-stamp the best, show the top 3, and learn from operator overrides via a feedback ledger (migration 186).
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:21Z
updated: 2026-07-01T08:40:00Z
---

# Voice Casting: 3-Candidate Chooser, Auto-Select & Learning Loop

This is the **selection layer** that sits on top of the harvest/isolation machinery in [[voice-scrape-isolation-pipeline]] and [[voice-isolation-pipeline]]. Where those pages cover *discovery → RunPod isolation → acceptance gate*, this covers *what happens once clips are banked*: rank them, auto-pick the best, present the top 3, and learn from operator corrections. Feature entry: the "Voice — {character.name}" modal (`apps/web/app/components/creators/character-voice-button.tsx`, **genome-only** — every POST hardcodes `characterType:'genome'`). ^[extracted]

## Rank → auto-select → show 3

- **Harvest banks the top clips** (not just one) to `harvested_voices`, isolated **in parallel** (see the speed note below). ^[extracted]
- `rankHarvestedVoices` (`packages/integrations/src/voice-match.ts`) orders *all* candidates against the character profile with a per-candidate **`%fit` confidence + rationale**. ^[extracted]
- `pickWithDemographicGate` enforces a **wrong-gender reject** before anything is stamped — the acceptability gate runs even at N=1, per [[single-candidate-bypasses-quality-gate]]. ^[extracted]
- Rank **#1 is auto-stamped** (`voice_mode:'automatic'`, `voice_sample_url`, `voice_reference_text`, `voice_harvested_id`); the **top set is persisted to `voice_candidates`** so the operator can switch to #2/#3 instantly without re-scraping. The modal shows up to 3 cards (audio preview, `%fit`, rationale, transcript, "Auto-selected · best fit" highlight) and falls back to the old single-voice view when only one is found. ^[extracted]

## The learning loop ("learn why we got it wrong")

A reusable **auto-pick + record-every-decision + feed-corrections-back-into-the-prompt** loop:

- `voice_candidate_feedback` (table) is the **learning ledger**: every candidate shown, the auto-pick, the operator's action (`approved` / `overridden_to` / `rejected`) + reason, **the ranker's own confidence + rationale**, and the character traits. `POST { mode:'select' }` and `reject` both write this signal. ^[extracted]
- `loadVoiceLessons` (`trigger/jobs/lib/character-voice-selection.ts`) aggregates past overrides/rejections — **this character first, then trait-similar characters** — and injects them into the ranker prompt as "learned corrections", so the ranker stops repeating the same mis-picks on the next cast. ^[extracted]

The general shape (rank with self-reported confidence → auto-act on #1 but keep the alternates → log the human's accept/override with the model's own confidence → replay corrections into the next prompt, nearest-entity-first) transfers to any "model proposes, operator disposes" selection UI. ^[inferred]

## Data model — migration 186

`186_voice_candidate_learning.sql` adds the `voice_candidates` column (both `genome` + `ai_slop` character tables) and the `voice_candidate_feedback` table. **Applied to prod** (`qoobzhuqmfnkfzoytodd`, "Stratton dash") via the Supabase MCP recorded path and verified live (columns, table, RLS, 2 policies, 4 indexes) — and since staging **shares the prod Supabase DB**, it landed for both. Backend was written to **degrade gracefully** if the column/table is absent: auto-select still works; the 3-way switch and learning stay inert until the migration lands. ^[extracted]

## Speed: the "10 minutes" was cold starts, not GPU

The feature felt terribly slow (~10 min). Isolation itself is **<1s/clip** — the wall-clock was **RunPod serverless cold-starts × sequential isolation**. Fixed by warming the endpoint (`idleTimeout 30→200s`, `maxWorkers 2→4`, min still 0 = no idle cost) so the worker survives between clips in a run, and by making isolation a **parallel worker pool** (4 concurrent). Full reusable lesson: [[runpod-serverless-cold-start-latency]]; platform: [[runpod]]. ^[extracted]

Part of [[stratton-internal]]. Related: [[scrape-creators]] (discovery), [[trigger-dev]] (job runtime).
