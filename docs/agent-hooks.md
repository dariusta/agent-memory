# Cross-Agent Wiki Auto-Distill

Every coding agent on this machine auto-distills its sessions into this wiki
(`wiki/`) when a chat ends or context is compacted. All hooks call one shared,
guarded script: [`bin/wiki-distill.sh`](../bin/wiki-distill.sh), which spawns a
detached, headless `claude -p` that reads the ending session's transcript and
distills durable knowledge via the `wiki-update` skill, then self-commits `wiki/`.

## Guarantees
- **recursion-safe** — sets `WIKI_DISTILL=1`; the distill's own hooks short-circuit
- **non-blocking** — detaches; the parent agent exits instantly
- **transcript-gated** — no real transcript (or <2KB) → no spawn; kills the ephemeral
  `claude -p` flood that used to waste money and starve real sessions
- **per-session debounce** — a session distills at most once per `WIKI_DISTILL_DEBOUNCE`
  (default 900s) for recurring turn/compaction events; true session-end events fire
  once on new content. Keyed per-session, so one session never blocks another.
- **off-switch** — `touch ~/.wiki-distill.disabled`

## How each agent passes its transcript (they all differ)
| Agent | Hook file | Events | Transcript source |
|---|---|---|---|
| Claude Code | `~/.claude/settings.json` → `hooks` | SessionEnd (terminal) + PreCompact | stdin JSON `.transcript_path` (JSONL) |
| Gemini CLI | `~/.gemini/settings.json` → `hooks` | SessionEnd (terminal) + PreCompress | stdin JSON `.transcript_path` (JSONL) |
| pi | `~/.pi/agent/extensions/wiki-distill.ts` | session_shutdown(quit, terminal) + session_compact | `ctx.sessionManager.getSessionFile()` → arg `$2` |
| Codex | `<repo>/.codex/hooks.json` (per-project) + `~/.codex/hooks.json` (home) | Stop (per-turn) + PreCompact | hook `jq`s stdin `.transcript_path` → arg `$2` |
| opencode | `~/.config/opencode/plugins/wiki-distill.js` (+ mavis mirror) | session.compacted + session.idle (per-turn) | **no file** — passes `sessionID` + SQLite DB path (`$2`,`$3`); script rebuilds via `sqlite3` |

### Notes / limitations
- **Codex has no global hooks and no session-end.** Hooks are per-project
  (`.codex/hooks.json`), so it's installed in stratton-internal, kori, iphone-control,
  and `~` — add more repos by copying that file. `Stop` fires per-turn, so codex
  distills at most once per debounce window, not exactly at session end. Codex
  re-prompts to trust a `.codex/hooks.json` the first time it sees new content.
- **opencode / pi have no true session-end** either — they distill on
  compaction + idle/turn-end, debounced.
- **opencode reconstructs from SQLite** (`message`+`part` tables) into a temp file
  per run; no persistent transcript file exists.

## Control / cost
Each real session spawns one headless `claude` run (rate-limited per session).
Pause everywhere: `touch ~/.wiki-distill.disabled`. Tune: `WIKI_DISTILL_DEBOUNCE`
(seconds), `WIKI_DISTILL_MIN_BYTES`. Logs: `.vault-meta/distill.log`.
