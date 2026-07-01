---
title: >-
    A Single Candidate Should Not Skip the Match/Quality Gate
category: skills
tags: [domain/ai, type/pattern, type/decision, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    When a matcher only runs with 2+ candidates, one lone candidate gets accepted blind and silently ships a mismatch. Keep the gate on for N=1, and backfill missing structured filters from available media (vision) instead of free-text tags.
provenance:
  extracted: 0.5
  inferred: 0.45
  ambiguous: 0.05
base_confidence: 0.58
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:08Z
updated: 2026-07-01T08:30:08Z
---

# A Single Candidate Should Not Skip the Match/Quality Gate

Two related traps, both seen live in [[stratton-internal]]'s [[voice-scraping-pipeline]] (a woman's voice got cast on a Black male founder), both generalizable to any "search → filter → link" flow.

## Trap 1 — the "only rank when there's a choice" short-circuit

A common shape: *"if there's more than one candidate, run the scoring/matcher to pick the best; otherwise just take the one we have."* The `else` branch is where mismatches ship — the lone candidate is **linked blind**, skipping the exact check (gender, identity, safety, schema fit) that the matcher exists to enforce. It reads as an optimization ("nothing to compare, why score?") but the gate isn't about *comparison*, it's about *acceptability*.

**Rule:** the acceptability gate must run at **N=1** too. With one candidate the matcher's job isn't to rank — it's to answer "is this even allowed?" and, on an explicit no-fit verdict, **reject and retry honestly** instead of stamping the mismatch. Keep it resilient: an *unavailable* gate (LLM/vision down) should fail open, but a *reachable* gate that says no must block.

Smell test: any code path where the count of candidates decides *whether the quality check runs at all* (vs. just how many it ranks) is suspect.

## Trap 2 — filtering on free-text tags when structured attributes are missing

The upstream cause was that the search query had no gender/ethnicity signal: the source record (an `ai_slop` character) had `gender: null` and only a free-text niche, and query derivation even *stripped* the demographic word out. Free-text vibe tags ("gravitas creator") don't constrain identity, so the search surfaced the wrong demographic before any gate could catch it.

**Rule:** when a structured filter attribute is missing, **derive it from the richest media you already hold** rather than leaning on free-text. Here the fix ran **Gemini vision on the character's reference face** to infer `{gender, ageRange, ethnicity}` and backfill the query. Precedence matters: **operator/explicit values always win**; inference only fills blanks (fire it *only when the field is missing*), so you never second-guess entered ground truth.

## Why it's worth remembering

Both failures are **silent** — the pipeline reports success ("Linked the cleanest of 1…"), so nothing looks broken until a human notices the output is wrong. The generalizable fix is the pairing: **backfill the filter so the right candidates surface**, *and* **keep the acceptability gate on for the single-candidate case** so a wrong one can't slip through unranked.
