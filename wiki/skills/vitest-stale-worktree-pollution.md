---
title: >-
    Vitest picks up stale .claude/worktrees siblings (false failures)
category: skills
tags: [type/gotcha, domain/testing, tool/vitest, tool/git, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Running vitest from a repo root also collects test files inside stale .claude/worktrees/* subtrees, which fail with unrelated @/ alias-resolution errors; scope with --root <app> to exclude them.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:30:39Z
updated: 2026-07-01T08:30:39Z
---

# Vitest picks up stale `.claude/worktrees` siblings

**Symptom.** You run `bun vitest run <some/test/paths>` from a repo root and get `FAIL` results in files under `.claude/worktrees/<name>/…` (e.g. `.claude/worktrees/determined-hoover-980584/apps/web/__tests__/…`) with errors like `@/` path-alias resolution failures — even though you never touched those files and your own suites pass.

**Cause.** Claude Code creates git worktrees under `.claude/worktrees/`, *inside* the repo tree. Vitest's file discovery, run from the repo root, globs those subtrees too and tries to load their (stale, differently-configured) test files. Their failures are **pre-existing and unrelated to your change** — an artifact of the worktree, not a regression.

**Fix / diagnosis.** Scope the run to the real project subtree so the sibling worktree is excluded:

```bash
# instead of from repo root:
bun vitest run --root apps/web scene-segment.test.ts model-duration.test.ts ...
```

Confirm the failing paths are all under `.claude/worktrees/` before dismissing them — if a failure is in your actual tree, it's real.

**General lesson.** Any git worktree nested *under* the repo root (`.claude/worktrees/`, ad-hoc `worktrees/`, etc.) pollutes repo-root test/lint/glob runs. Either scope the tool to the app subdir (`--root`), add the worktree dir to the tool's ignore globs, or keep worktrees outside the repo. Same class of issue applies to `biome`, `eslint`, `tsc` project globs, and grep sweeps. Related: [[stratton-internal]] uses `.claude/worktrees`; the Vitest `@/` alias only resolves when run from `apps/web/`.
