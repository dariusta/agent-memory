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
#   * Transcript-gated — only distills sessions that produced a real transcript,
#     so ephemeral `claude -p` / empty sessions never spawn a distill.
#   * Per-session dedupe — each distinct session state distills exactly once;
#     one session never blocks another (no global time-debounce / starvation).
#   * Safe-by-default — no-op if the `claude` CLI is absent; logs everything.
set -uo pipefail

VAULT="/Users/darius/Documents/agents"
META="$VAULT/.vault-meta"
LOG="$META/distill.log"
EVENT="${1:-session-end}"

log() { mkdir -p "$META" 2>/dev/null; printf '%s [%s] %s\n' "$(date -u +%FT%TZ)" "$EVENT" "$*" >>"$LOG" 2>/dev/null; }

# 0) Global kill-switch: `touch ~/.wiki-distill.disabled` to turn auto-distill off everywhere.
if [ -f "$HOME/.wiki-distill.disabled" ]; then exit 0; fi

# 1) Recursion guard: never distill from inside a distill run.
if [ "${WIKI_DISTILL:-}" = "1" ]; then exit 0; fi

# 2) Need the headless engine.
if ! command -v claude >/dev/null 2>&1; then log "skip: no claude CLI on PATH"; exit 0; fi

mkdir -p "$META" 2>/dev/null

# 3) Read the hook payload + resolve the session transcript FIRST — gating needs it.
#    Claude/Codex/Gemini pass JSON with a transcript path; opencode/pi pass none.
PAYLOAD="$(cat 2>/dev/null || true)"
TRANSCRIPT=""
if [ -n "$PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // .transcript // .session.path // empty' 2>/dev/null || true)"
fi

# 4) GATE on a real transcript. Core fix: the old code distilled EVERY session
#    (incl. ephemeral home-dir `claude -p` runs with no transcript), wasting spawns
#    and — via the old global time-debounce — starving the sessions that mattered.
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  log "skip: no transcript on disk — nothing to distill"; exit 0
fi
MIN_BYTES="${WIKI_DISTILL_MIN_BYTES:-2000}"
tsize=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ' || echo 0)
if [ "${tsize:-0}" -lt "$MIN_BYTES" ]; then
  log "skip: transcript too small (${tsize}B < ${MIN_BYTES}B) — trivial session"; exit 0
fi

# 5) PER-SESSION dedupe (replaces the global time-debounce that caused starvation).
#    Key on transcript path+size+mtime: each distinct session STATE distills once;
#    a duplicate re-fire is skipped, but OTHER sessions are never blocked.
mkdir -p "$META/distilled" 2>/dev/null
tmtime=$(stat -f %m "$TRANSCRIPT" 2>/dev/null || stat -c %Y "$TRANSCRIPT" 2>/dev/null || echo 0)
KEY="$(printf '%s:%s:%s' "$TRANSCRIPT" "$tsize" "$tmtime" | shasum 2>/dev/null | cut -d' ' -f1)"
[ -z "$KEY" ] && KEY="${tsize}_${tmtime}"
if [ -e "$META/distilled/$KEY" ]; then log "skip: already distilled this session state"; exit 0; fi
: > "$META/distilled/$KEY"

CTX_FILE="$META/distill-ctx.txt"
{ echo "Triggering agent event: $EVENT"; echo "Session transcript: $TRANSCRIPT"; } >"$CTX_FILE" 2>/dev/null

PROMPT="A coding-agent session just ended (event: $EVENT). Read the context file $CTX_FILE; if it names a transcript file, read that transcript. Then use the wiki-update skill to distill any DURABLE, reusable knowledge (decisions, architecture, gotchas, how-tos) from that session into the Obsidian wiki at $VAULT/wiki, and refresh wiki/hot.md. Be conservative: if nothing meaningful or reusable happened, make no changes and stop. Do not ask questions; run non-interactively."

# 6) Spawn detached + recursion-guarded; survive parent exit.
#    claude runs to completion, THEN we self-commit the wiki: the claude-obsidian
#    plugin's auto-commit PostToolUse hook does not fire in headless `-p` mode.
log "spawning headless distill (transcript=${TRANSCRIPT:-none})"
(
  cd "$VAULT" 2>/dev/null || exit 0
  WIKI_DISTILL=1 nohup claude -p "$PROMPT" --permission-mode acceptEdits >>"$LOG" 2>&1
  if [ -d .git ] && [ ! -f .vault-meta/auto-commit.disabled ]; then
    # Stage each path independently (a missing/empty path must not abort the rest),
    # then commit the staged index WITHOUT a pathspec — `git commit -- <pathspec>`
    # fatally errors if any listed pathspec has nothing staged.
    for p in wiki .raw .vault-meta/mode.json; do
      [ -e "$p" ] && git add -A -- "$p" 2>/dev/null || true
    done
    if git diff --cached --quiet 2>/dev/null; then
      log "distill complete: no wiki changes to commit"
    else
      git commit -q -m "wiki: auto-distill ($EVENT) $(date '+%Y-%m-%d %H:%M')" 2>/dev/null && log "self-committed wiki changes"
    fi
  fi
) </dev/null >>"$LOG" 2>&1 &
disown 2>/dev/null || true
exit 0
