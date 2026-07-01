#!/usr/bin/env bash
# wiki-distill.sh — auto-distill a just-finished agent session into the Obsidian wiki.
#
# Wired into the session-end / compaction / turn-end hooks of Claude Code, Codex,
# opencode, pi, and Gemini CLI (see <vault>/docs/agent-hooks.md). It spawns a
# guarded, detached, headless `claude -p` that reads the ending session's
# transcript and distills durable knowledge into the wiki via the wiki-update skill.
#
# Transcript source per agent (they all differ):
#   Claude / Gemini -> stdin JSON, key .transcript_path            (JSONL file)
#   Codex / pi      -> transcript file path passed as $2           (JSONL file)
#   opencode        -> NO file; $2=sessionID, $3=sqlite DB path    (reconstructed here)
#
# Guarantees:
#   * recursion-safe        — WIKI_DISTILL=1 short-circuits the distill's own hooks
#   * non-blocking          — detaches so the parent agent exits immediately
#   * transcript-gated      — no real transcript => no spawn (kills ephemeral junk)
#   * per-session debounced — a session distills at most once per $WIKI_DISTILL_DEBOUNCE
#                             for recurring (turn-end/compaction) events; terminal
#                             session-end events bypass the rate limit. One session
#                             never blocks another.
#   * safe-by-default       — no-op if the `claude` CLI is absent; logs everything.
set -uo pipefail

VAULT="/Users/darius/Documents/agents"
META="$VAULT/.vault-meta"
LOG="$META/distill.log"
EVENT="${1:-session-end}"
ARG2="${2:-}"
ARG3="${3:-}"
MIN_BYTES="${WIKI_DISTILL_MIN_BYTES:-2000}"
DEBOUNCE="${WIKI_DISTILL_DEBOUNCE:-900}"   # per-session rate limit (s) for recurring events

log() { mkdir -p "$META" 2>/dev/null; printf '%s [%s] %s\n' "$(date -u +%FT%TZ)" "$EVENT" "$*" >>"$LOG" 2>/dev/null; }
cleanup_tmp() { [ -n "${TMP_TRANSCRIPT:-}" ] && rm -f "$TMP_TRANSCRIPT" 2>/dev/null; return 0; }

# 0) kill-switch, recursion guard, engine present.
[ -f "$HOME/.wiki-distill.disabled" ] && exit 0
[ "${WIKI_DISTILL:-}" = "1" ] && exit 0
command -v claude >/dev/null 2>&1 || { log "skip: no claude CLI on PATH"; exit 0; }
mkdir -p "$META/distilled" 2>/dev/null

# 1) Resolve the session transcript into a local file $TRANSCRIPT (+ an identity key).
TRANSCRIPT=""; TMP_TRANSCRIPT=""; IDKEY=""
case "$EVENT" in
  opencode-*)
    # opencode has no per-session transcript file — reconstruct from its SQLite DB.
    SID="$ARG2"; DB="$ARG3"
    case "$SID" in *[!A-Za-z0-9_-]*|"") log "skip: opencode bad/empty session id"; exit 0;; esac
    [ -f "$DB" ] || { log "skip: opencode db not found ($DB)"; exit 0; }
    command -v sqlite3 >/dev/null 2>&1 || { log "skip: no sqlite3 for opencode"; exit 0; }
    TMP_TRANSCRIPT="$(mktemp "${TMPDIR:-/tmp}/wikidistill-oc.XXXXXX" 2>/dev/null)"  # X's must trail (BSD mktemp)
    sqlite3 -readonly "$DB" \
      "SELECT json_extract(m.data,'\$.role')||': '||COALESCE(json_extract(p.data,'\$.text'),'') \
       FROM message m JOIN part p ON p.message_id=m.id \
       WHERE m.session_id='$SID' AND json_extract(p.data,'\$.type')='text' \
       ORDER BY m.time_created, p.time_created;" >"$TMP_TRANSCRIPT" 2>/dev/null
    TRANSCRIPT="$TMP_TRANSCRIPT"; IDKEY="opencode:$SID"
    ;;
  *)
    # Everyone else: path in $2 (Codex/pi) or stdin JSON .transcript_path (Claude/Gemini).
    TRANSCRIPT="$ARG2"
    if [ -z "$TRANSCRIPT" ]; then
      PAYLOAD="$(cat 2>/dev/null || true)"
      if [ -n "$PAYLOAD" ] && command -v jq >/dev/null 2>&1; then
        TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // .transcript // .session.path // empty' 2>/dev/null || true)"
      fi
    fi
    IDKEY="$TRANSCRIPT"
    ;;
esac

# 2) Gate: require a real, non-trivial transcript.
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  cleanup_tmp; log "skip: no transcript on disk — nothing to distill"; exit 0
fi
tsize=$(wc -c <"$TRANSCRIPT" 2>/dev/null | tr -d ' '); tsize="${tsize:-0}"
if [ "$tsize" -lt "$MIN_BYTES" ]; then
  cleanup_tmp; log "skip: transcript too small (${tsize}B < ${MIN_BYTES}B) — trivial session"; exit 0
fi

# 3) Per-session dedupe/debounce keyed on session identity (transcript path / opencode id).
KEY="$(printf '%s' "$IDKEY" | shasum 2>/dev/null | cut -d' ' -f1)"
[ -z "$KEY" ] && KEY="$(printf '%s' "$IDKEY" | md5 2>/dev/null)"
MARK="$META/distilled/$KEY"
lastsize=0; lasttime=0; [ -f "$MARK" ] && read -r lastsize lasttime <"$MARK" 2>/dev/null
now=$(date +%s)
if [ "$tsize" -le "${lastsize:-0}" ]; then
  cleanup_tmp; log "skip: no new content since last distill"; exit 0
fi
case "$EVENT" in
  claude-sessionend|gemini-end|pi-shutdown|session-end|live-test) : ;;   # terminal: distill new content now
  *) if [ $((now - ${lasttime:-0})) -lt "$DEBOUNCE" ]; then
       cleanup_tmp; log "skip: per-session debounce ($((now-${lasttime:-0}))s < ${DEBOUNCE}s)"; exit 0
     fi ;;
esac
printf '%s %s\n' "$tsize" "$now" >"$MARK"

PROMPT="A coding-agent session just ended or compacted (event: $EVENT). Read the session transcript file at $TRANSCRIPT, then use the wiki-update skill to distill any DURABLE, reusable knowledge (decisions, architecture, gotchas, how-tos) from it into the Obsidian wiki at $VAULT/wiki, and refresh wiki/hot.md. Be conservative: if nothing meaningful or reusable happened, make no changes and stop. Do not ask questions; run non-interactively."

# 4) Spawn detached + recursion-guarded; run to completion, clean temp, self-commit.
#    (The claude-obsidian auto-commit hook does not fire in headless `-p` mode.)
log "spawning headless distill (event=$EVENT transcript=$TRANSCRIPT ${tsize}B)"
(
  cd "$VAULT" 2>/dev/null || exit 0
  WIKI_DISTILL=1 nohup claude -p "$PROMPT" --permission-mode acceptEdits >>"$LOG" 2>&1
  [ -n "${TMP_TRANSCRIPT:-}" ] && rm -f "$TMP_TRANSCRIPT" 2>/dev/null
  if [ -d .git ] && [ ! -f .vault-meta/auto-commit.disabled ]; then
    for p in wiki .raw .vault-meta/mode.json; do [ -e "$p" ] && git add -A -- "$p" 2>/dev/null || true; done
    if git diff --cached --quiet 2>/dev/null; then log "distill complete: no wiki changes to commit"
    else git commit -q -m "wiki: auto-distill ($EVENT) $(date '+%Y-%m-%d %H:%M')" 2>/dev/null && log "self-committed wiki changes"; fi
  fi
) </dev/null >>"$LOG" 2>&1 &
disown 2>/dev/null || true
exit 0
