# Cross-Agent Wiki Auto-Distill

Every coding agent on this machine auto-distills its sessions into this wiki
(`wiki/`) when a chat ends or context is compacted. All hooks call one shared,
guarded script: [`bin/wiki-distill.sh`](../bin/wiki-distill.sh).

## How it works
`bin/wiki-distill.sh` spawns a **detached, headless `claude -p`** run that reads
the ending session's transcript and uses the `wiki-update` skill to distill
durable knowledge into `wiki/`, refreshing `wiki/hot.md`. It is:
- **recursion-safe** — sets `WIKI_DISTILL=1`; nested distill sessions short-circuit,
- **debounced** — `WIKI_DISTILL_DEBOUNCE` seconds (default 120),
- **non-blocking** — detaches so the parent agent exits instantly,
- **off-switchable** — `touch ~/.wiki-distill.disabled` to disable everywhere.

## Wiring per agent
| Agent | File | Events | Notes |
|---|---|---|---|
| Claude Code | `~/.claude/settings.json` → `hooks` | `SessionEnd`, `PreCompact` | Global (every project). In-session memory loop comes from the claude-obsidian plugin (`Stop`/`PostToolUse`). |
| Codex | `~/.codex/hooks.json` | `PreCompact` (manual+auto) | No true session-end event exists; `Stop` is per-turn (too noisy), so compaction only. |
| opencode | `~/.config/opencode/plugins/wiki-distill.js` | `session.compacted` | No session-end; `session.idle` is per-turn, so compaction only. |
| pi | `~/.pi/agent/extensions/wiki-distill.ts` | `session_shutdown` (quit), `session_compact` | Full coverage. |
| Gemini CLI | `~/.gemini/settings.json` → `hooks` | `SessionEnd`, `PreCompress` | Full coverage. SessionEnd doesn't wait, but the script detaches so work survives exit. |

## Cost / control
Each trigger spawns one headless `claude` run. To pause: `touch ~/.wiki-distill.disabled`.
To resume: remove that file. Logs: `.vault-meta/distill.log`.
