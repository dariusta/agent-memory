#!/usr/bin/env bash
# wiki-distill.sh — auto-distill a just-finished agent session into the Obsidian wiki.
#
# Wired into the session-end / compaction hooks of Claude Code, Codex, opencode,
# pi, and Gemini CLI (see <vault>/docs/agent-hooks.md). It spawns a guarded,
# detached, headless `claude -p` run that reads the ending session's transcript
# and distills durable knowledge into the wiki via the wiki-update skill.
#
# Design guarantees:
#   * Recursion-safe — the headless run is itself a Claude session whose own
#     SessionEnd hook calls this script; WIKI_DISTILL=1 short-circuits that.
#   * Non-blocking — detaches so the parent agent exits immediately.
#   * Debounced — skips if it ran in the last $DEBOUNCE_SECONDS (tames per-turn
#     events on agents that lack a true session-end signal).
#   * Safe-by-default — no-op if the `claude` CLI is absent; logs everything.
set -uo pipefail

VAULT="/Users/darius/Documents/agents"
META="$VAULT/.vault-meta"
LOG="$META/distill.log"
STAMP="$META/distill.last"
DEBOUNCE_SECONDS="${WIKI_DISTILL_DEBOUNCE:-120}"
EVENT="${1:-session-end}"

log() { mkdir -p "$META" 2>/dev/null; printf '%s [%s] %s\n' "$(date -u +%FT%TZ)" "$EVENT" "$*" >>"$LOG" 2>/dev/null; }

# 0) Global kill-switch: `touch ~/.wiki-distill.disabled` to turn auto-distill off everywhere.
if [ -f "$HOME/.wiki-distill.disabled" ]; then exit 0; fi

# 1) Recursion guard: never distill from inside a distill run.
if [ "${WIKI_DISTILL:-}" = "1" ]; then exit 0; fi

# 2) Need the headless engine.
if ! command -v claude >/dev/null 2>&1; then log "skip: no claude CLI on PATH"; exit 0; fi

mkdir -p "$META" 2>/dev/null

# 3) Debounce.
now=$(date +%s)
if [ -f "$STAMP" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  if [ $((now - last)) -lt "$DEBOUNCE_SECONDS" ]; then log "skip: debounced ($((now - last))s < ${DEBOUNCE_SECONDS}s)"; exit 0; fi
fi
echo "$now" >"$STAMP"

# 4) Capture the hook payload from stdin (Claude/Codex/Gemini send JSON; others may not).
PAYLOAD="$(cat 2>/dev/null || true)"
TRANSCRIPT=""
if [ -n "$PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // .transcript // .session.path // empty' 2>/dev/null || true)"
fi

CTX_FILE="$META/distill-ctx.txt"
{
  echo "Triggering agent event: $EVENT"
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    echo "Session transcript: $TRANSCRIPT"
  elif [ -n "$PAYLOAD" ]; then
    echo "Hook payload (no transcript path found):"
    printf '%s\n' "$PAYLOAD" | head -c 4000
  else
    echo "(no payload provided by this agent's hook)"
  fi
} >"$CTX_FILE" 2>/dev/null

PROMPT="A coding-agent session just ended (event: $EVENT). Read the context file $CTX_FILE; if it names a transcript file, read that transcript. Then use the wiki-update skill to distill any DURABLE, reusable knowledge (decisions, architecture, gotchas, how-tos) from that session into the Obsidian wiki at $VAULT/wiki, and refresh wiki/hot.md. Be conservative: if nothing meaningful or reusable happened, make no changes and stop. Do not ask questions; run non-interactively."

# 5) Spawn detached + recursion-guarded; survive parent exit.
log "spawning headless distill (transcript=${TRANSCRIPT:-none})"
(
  cd "$VAULT" 2>/dev/null || exit 0
  WIKI_DISTILL=1 nohup claude -p "$PROMPT" --permission-mode acceptEdits \
    >>"$LOG" 2>&1 &
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0
