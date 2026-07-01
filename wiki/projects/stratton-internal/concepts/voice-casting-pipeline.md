---
title: >-
    Voice Casting / Scrape-and-Match Pipeline (stratton-internal)
category: concepts
tags: [domain/ai, domain/web, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    How mimic casts an AI character's voice: one /api/characters/voice route with 6 modes, a Trigger.dev scrape job that harvests real creators, RunPod clip isolation, then Fish Audio / ElevenLabs cloning — plus the demographic gate.
provenance:
  extracted: 0.72
  inferred: 0.23
  ambiguous: 0.05
base_confidence: 0.68
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:08Z
updated: 2026-07-01T08:30:08Z
---

# Voice Casting / Scrape-and-Match Pipeline (stratton-internal)

How [[stratton-internal]] gives an AI character a voice. One character has a *voice-casting profile*; casting it means either linking an uploaded reference clip, or **scraping real creators** who match the character, isolating a clean clip, and cloning it. Everything funnels through a single API route with a `mode` switch, backed by a Trigger.dev background job.

## The one route, six modes

`apps/web/app/api/characters/voice/route.ts` — **POST** dispatches on `mode`:

- `scrape` — enqueue background voice discovery via [[trigger-dev]] (`scrapeCharacterVoice` job).
- `automatic` — match a voice from the already-harvested library (no fresh scrape).
- `isolate` — approve a preview candidate for GPU isolation.
- `manual` — link an operator-uploaded reference clip.
- `fishaudio` — clone the linked voice into a Fish Audio model.
- `elevenlabs` — clone the linked voice into an ElevenLabs model.

**GET** polls background-job status for the `scrape` and `isolation` tasks (they run async, so the UI long-polls).

Two profile loaders sit behind it: `loadScrapeProfile()` builds the **structured signal used for discovery** (what to search for), while `loadProfile()` loads the **voice-casting profile** (what's already linked). ^[extracted]

## The scrape job (the heavy path)

`trigger/jobs/scrape-character-voice.ts` runs the discovery pipeline:

1. Derive search queries from the profile via `deriveDiscoveryQueries` / `expandCharacterVoiceDiscoveryQueries`.
2. Scrape candidate creators off TikTok (via [[scrape-creators]]), pull clips.
3. Isolate a clean voice clip on **RunPod (GPU)**; `bankRunPodVoiceClip()` stores it in Supabase storage + the **`harvested_voices`** table; `finalizeRunPodVoiceIsolation()` banks the clip and stamps the character. ^[extracted]
4. Pick the best clip. `pickHarvestedVoice` is a **gender/demographic-aware matcher** — but historically it only ran when there was **more than one** clip.

Harvested clips accumulate in `harvested_voices`, which is what the `automatic` (library-match) mode later draws from — the scrape both casts *this* character and grows a reusable library.

## Discovery signal depends on character type — the sharp edge

`loadScrapeProfile()` returns different fidelity per character type. For an **`ai_slop`** character the niche string *is* its `category_tags` (e.g. `black creator | black calm enterprise gravitas`), and the loader returns **`gender: null`** with no `ethnicity` — only tags + vibe. Consequences that compounded into a real casting bug (2026-06-30):

- Query derivation gets **no gender/ethnicity**, and even **strips "black" out** of the niche → the TikTok search collapses to something like "gravitas creator" and surfaces mixed-gender creators.
- The job runs with `maxClips: 1`; the gender-aware matcher only fired for **>1** clip, so a single clean clip was **linked blind** ("Linked the cleanest of 1…") → a woman's voice on a Black male B2B founder.
- The character's **reference face** (`reference_image_urls` → `baseReferenceUrl`) was loaded into the profile but **never used**.

See [[single-candidate-bypasses-quality-gate]] for the reusable version of the failure.

## Vision pre-analysis + hard demographic gate (the fix, now baked in)

The pipeline now backfills the missing structured signal from the media it already has, and refuses to link a mismatch:

- **`deriveScrapeTraitsFromFace()`** (`packages/integrations/src/voice-scrape.ts`, Gemini vision) reads `{gender, ageRange, ethnicity}` off the reference face **only when the DB gender is missing**, and fills the scrape profile (`applyFaceTraitsToProfile` / `faceTraitLines` helpers). **Explicit operator/genome values always win** — it never overrides entered data. The query becomes "black man …" instead of "gravitas creator". ^[extracted]
- The route carries the inferred lines to the job as `inferredTraits`; the job's new **`pickWithDemographicGate`** runs the matcher **even for a single clip** when any demographic signal exists, and an explicit no-fit verdict **rejects the link** (honest retry message) rather than stamping a mismatched voice. Applied to both the fresh-scrape and library-fallback selection paths. Stays resilient: an **unavailable matcher never rejects**. ^[extracted]

Design choice worth revisiting: vision inference fires *only when gender is missing*, so it never second-guesses operator-entered genome data. Making it always run (and correct wrong DB values) was flagged as a future option. ^[inferred]

## Verification boundary

Not observable in a browser preview — it's a background Gemini-vision → TikTok scrape → RunPod GPU pipeline with nothing to render, so it's validated by unit tests over the pure helpers (`packages/integrations/src/voice-scrape.test.ts`) + typecheck, not a dev server. Trigger job files live outside the app typecheck config, so they were validated with a temp tsconfig extending root. ^[extracted]
