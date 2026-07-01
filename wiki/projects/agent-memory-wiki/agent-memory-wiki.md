---
title: >-
    agent-memory-wiki
category: projects
tags: [domain/tooling, domain/infra, type/architecture]
sources: [projects/agent-memory-wiki]
summary: >-
    The cross-agent auto-distill memory system: every coding agent on this machine funnels its ending/compacting sessions through one guarded script that headlessly distills durable knowledge into this Obsidian wiki.
provenance:
  extracted: 0.55
  inferred: 0.4
  ambiguous: 0.05
base_confidence: 0.6
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T04:22:28Z
updated: 2026-07-01T04:22:28Z
---

# agent-memory-wiki

The repo at `/Users/darius/Documents/agents` is both the **Obsidian vault** (`wiki/`) and the **cross-agent auto-distill engine** that fills it. Every coding agent on this machine — Claude Code, Codex, opencode, pi, Gemini CLI — is hooked so that when a chat ends or context compacts, it distills its own session into the wiki. All hooks call one shared, guarded script, `bin/wiki-distill.sh`, which spawns a detached headless `claude -p` that reads the ending transcript and runs the `wiki-update` skill, then self-commits `wiki/`. It also integrates the [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) engine.

**Full wiring lives in the repo — read those first, don't re-derive:** `docs/agent-hooks.md` (the per-agent hook table) and `bin/wiki-distill.sh` (the guarded spawner). This page captures the *reasoning and the gotchas* that the code only hints at.

## Key design decisions (the "why")

- **One shared script, five different transcript sources.** The hard part isn't distilling — it's that every agent exposes its transcript differently: Claude/Gemini put a JSONL path in stdin JSON (`.transcript_path`); Codex/pi pass a JSONL path as `$2`; **opencode passes no file at all** — just a `sessionID` + SQLite DB path, and the script rebuilds the transcript via `sqlite3`. See [[opencode-transcript-storage]].
- **Transcript-gate before spawning.** Early versions spawned a headless `claude -p` on every trivial/empty event, producing an ephemeral-run flood that wasted money and starved real sessions. Now: no real transcript, or `< WIKI_DISTILL_MIN_BYTES` (2 KB), → no spawn.
- **Per-session debounce, keyed per session.** Turn-end / idle / compaction events recur many times per session; the dedupe key is the session identity (transcript path, or `opencode:<sid>`), and a session distills at most once per `WIKI_DISTILL_DEBOUNCE` (900 s). Keying per-session means one busy session never blocks another. **Terminal** session-end events (`claude-sessionend`, `gemini-end`, `pi-shutdown`) bypass the rate limit and distill new content immediately; only recurring events are debounced. It also skips when the transcript hasn't grown since the last distill (`tsize <= lastsize`).
- **Recursion-safe + non-blocking.** The spawn sets `WIKI_DISTILL=1` so the distill's own session-end hook short-circuits, and it detaches (`nohup … & disown`) so the parent agent exits instantly.
- **The script self-commits.** Because the claude-obsidian auto-commit hook does not fire under headless `claude -p`, the script does its own `git add`/`commit` of `wiki/` after the run. See [[claude-headless-p-hooks-dont-fire]].
- **Kill-switch:** `touch ~/.wiki-distill.disabled`. Logs: `.vault-meta/distill.log`.

## Gotchas hit while building

- **Codex has no global hooks and no session-end.** Hooks are per-project (`.codex/hooks.json`), installed per-repo (stratton-internal, kori, iphone-control, `~`); add a repo by copying that file. Its `Stop` event fires per-turn, so Codex distills at most once per debounce window, not exactly at end. Codex re-prompts to trust a new `.codex/hooks.json` the first time.
- **opencode / pi have no true session-end either** — they distill on compaction + idle/turn-end, debounced.
- **An opencode hook can silently never fire** if opencode loads plugins from a different config dir than you installed into — verify the actual load dir before debugging the plugin. See [[opencode-transcript-storage]].

## What it distills into

The vault's project pages are produced by this system: [[stratton-internal]], [[kori]], [[iphone-control]]. Reusable, external-tool lessons surfaced while building it: [[opencode-transcript-storage]], [[claude-headless-p-hooks-dont-fire]].
