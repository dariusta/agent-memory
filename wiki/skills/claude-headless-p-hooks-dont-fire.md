---
title: >-
    Interactive/Plugin Hooks Don't Fire Under `claude -p`
category: skills
tags: [domain/tooling, type/reference]
sources: [projects/agent-memory-wiki]
summary: >-
    A headless `claude -p` run did not fire the claude-obsidian plugin's PostToolUse auto-commit hook — so any side effect a downstream hook normally provides must be done explicitly by the wrapping script.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T04:22:28Z
updated: 2026-07-01T04:22:28Z
---

# Interactive/Plugin Hooks Don't Fire Under `claude -p`

**Observed:** a headless `claude -p` distill run wrote a new wiki page but left it **untracked — HEAD didn't move**. The claude-obsidian plugin's `PostToolUse` auto-commit hook, which commits reliably in interactive sessions, **did not run** in the `-p` (print/headless) invocation. ^[extracted]

**Generalization (treat as a rule for headless automation):** do not rely on interactive- or plugin-provided hooks to run inside a `claude -p` subprocess. If a downstream side effect matters (git commit, formatting, notifications), the **wrapping script must perform it explicitly** after the headless run returns. ^[inferred]

**How the distiller works around it:** `bin/wiki-distill.sh` spawns the headless `claude -p`, waits for it, then does its own `git add`/`git commit` of `wiki/` — it never assumes the plugin's auto-commit fired. See [[agent-memory-wiki]].

Corollary for any `claude -p` pipeline: verify the end-state you need (a commit, a moved file, a sent message) directly rather than assuming a hook produced it. Related tool gotcha: [[opencode-transcript-storage]].
