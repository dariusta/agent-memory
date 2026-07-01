---
title: >-
    opencode Stores Transcripts in SQLite, Not Files
category: skills
tags: [domain/tooling, type/reference]
sources: [projects/agent-memory-wiki]
summary: >-
    opencode 1.17.x keeps all session messages in a SQLite DB (opencode.db), not per-session JSON files, and has no export CLI — reconstruct a transcript by querying message + part tables.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.78
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T04:22:28Z
updated: 2026-07-01T04:22:28Z
---

# opencode Stores Transcripts in SQLite, Not Files

If you need a coding-agent's session transcript, most tools hand you a JSONL file path (Claude Code, Gemini, Codex, pi). **opencode does not.** Verified on opencode **1.17.12** (binary `~/.opencode/bin/opencode`):

- All session data lives in one **SQLite database**: `~/.local/share/opencode/opencode.db` (9.9 GB on this machine — it is the whole history, not per-session files).
- `~/.local/share/opencode/storage/` holds only `session_diff/ses_<id>.json` (per-session file diffs, not the conversation) and `migration/`. There is **no** `message/` dir and **no** per-session transcript file. ^[extracted]
- There is **no `opencode session export`** command — only `session list` and `session delete`. ^[extracted]

## Data-dir resolution order

`$OPENCODE_DATA` → else `$XDG_DATA_HOME/opencode` → else `~/.local/share/opencode`. The DB is `<data-dir>/opencode.db`.

## Reconstructing a transcript from a session ID

The conversation text lives in the `part` table (`data` JSON, `type:"text"`, `text:"…"`), linked to `message` (role, model, tokens) by `message_id`, keyed by `session_id`. Verified-working reconstruction:

```sql
SELECT json_extract(m.data,'$.role') || ': ' || COALESCE(json_extract(p.data,'$.text'),'')
FROM message m
JOIN part p ON p.message_id = m.id
WHERE m.session_id = ?               -- e.g. 'ses_0e4d9802affekhY27ML37OBGGP'
  AND json_extract(p.data,'$.type') = 'text'
ORDER BY m.time_created, p.time_created;
```

Any tool wanting the transcript must open the DB (e.g. `sqlite3 -readonly`) keyed by `session_id`; it cannot be handed a file path. This is why the cross-agent distiller passes opencode's `sessionID` + DB path (not a transcript path) and rebuilds a temp file — see [[agent-memory-wiki]].

## Plugin wiring gotchas (why a hook silently never fires)

- Plugin auto-load glob is `{plugin,plugins}/*.{ts,js}`; `~/.config/opencode/plugins/wiki-distill.js` is valid with **no** `opencode.json` entry needed. ^[extracted]
- But opencode may load plugins from a **different config dir** than you expect (e.g. a `~/.mavis/…/opencode/plugins/` mirror seen in logs) — if your hook never fires, confirm *which* dir opencode is actually loading from before debugging the code. ^[inferred]
- Events: `session.compacted` and `session.idle` (the closest thing to session-end; fires every turn, so debounce per session). Both payloads are `{ sessionID }`; the hook receives `{ event: { id, type, properties } }`, so the id is at **`event.properties.sessionID`**. ^[extracted]

Related: [[claude-headless-p-hooks-dont-fire]].
