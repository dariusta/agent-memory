---
title: >-
    Instrument a Reject-Gate Before Tuning It
category: skills
tags: [domain/ai, domain/observability, type/pattern, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    When a strict quality/acceptance gate keeps rejecting inputs, log the rejection-reason distribution before loosening thresholds — make gate-vs-source a number, not a guess, and check the fallback path isn't dropping that signal.
provenance:
  extracted: 0.55
  inferred: 0.4
  ambiguous: 0.05
base_confidence: 0.6
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:29:48Z
updated: 2026-07-01T08:29:48Z
---

# Instrument a Reject-Gate Before Tuning It

When a pipeline runs inputs through a strict acceptance gate (quality filter, validator, threshold cascade) and the output is "0 accepted → fell back," the reflex is to loosen thresholds. **Don't guess — measure first.** The pipeline almost always knows *why* each input was rejected; the fix is to surface that distribution, not to blindly relax the bar. ^[inferred]

## The pattern

1. **Emit the rejection-reason distribution per run.** A `Record<reason, count>` (e.g. `input_too_short`, `multi_speaker_no_solo_window`, `windows_failed_quality_gate`, `budget_exhausted`, `isolation_timeout`) tells you in one line whether the problem is the **gate** (loosen thresholds) or the **source/input** (change what you feed it) or the **budget** (raise limits). ^[extracted]
2. **Check the fallback/success path isn't swallowing the signal.** The reason map often exists already but is **dropped on the exact path you care about** — the graceful "0 accepted, used the fallback" branch that reports success. In stratton-internal, `harvest.rejected` was computed but silently discarded when the job banked 0 clips and linked a library voice — the precise "why didn't it work" case. Make the diagnostic **always-on**, on every terminal path including graceful fallback. ^[extracted]
3. **Only then tune.** With the distribution in hand, gate-vs-source stops being an argument and becomes a decision. Loosening a gate you haven't measured risks degrading downstream quality (e.g. clone timbre) for no proven yield gain — especially if the gate was [[deployed-env-overrides-code-defaults|already loosened in prod]].

## Why it matters

Loosening thresholds is a lossy, one-way-feeling change with real downstream cost; logging a counter is cheap and reversible. **Cheapest highest-value move is almost always the instrumentation, not the tuning.** Worked example: [[voice-scrape-isolation-pipeline]] (part of [[stratton-internal]]).
