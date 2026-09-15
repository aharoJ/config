#!/bin/bash
# pane-watch: tell the operator, loudly, when an agent in a tmux pane is waiting on them.
#
# Design notes and the eight-round adversarial audit trail that produced the parser live in
# ./audits/. Two rules that everything else follows from:
#   1. Silence must never be the failure mode. Losing the ability to observe is itself an event.
#   2. "Process alive" and "coverage valid" are different claims. This script never conflates them.
set -u

usage() {
  cat >&2 <<'U'
usage: pane-watch --pane <tmux-target> --ui <grammar> [--hot-file FILE] [--ack-current] [--replace]

  --pane        REQUIRED. Any tmux target (%id, session:window, session:window.pane).
                Resolved immediately to an immutable pane id. No default, ever.
  --ui          REQUIRED. Named built-in UI grammar. Supported: codex
  --hot-file    Optional. Newline-separated extended regexes for the advisory HOT channel.
                Advisory only: never affects state, acknowledgment, coverage, or exit status.
  --ack-current Treat the turn on screen at arm time as already seen.
  --replace     Take over from an existing watcher on the same pane.

Exit codes: 0 clean, 1 refused to arm, 2 watch coverage lost, 3 capture failure.
U
  exit 64
}

TARGET=""; UI=""; HOTFILE=""; ACK_CURRENT=0; REPLACE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pane) TARGET="${2:-}"; shift 2 ;;
    --ui) UI="${2:-}"; shift 2 ;;
    --hot-file) HOTFILE="${2:-}"; shift 2 ;;
    --ack-current) ACK_CURRENT=1; shift ;;
    --replace) REPLACE=1; shift ;;
    -h|--help) usage ;;
    *) echo "REFUSE: unknown argument: $1" >&2; usage ;;
  esac
done
[ -n "$TARGET" ] || { echo "REFUSE: --pane is required. There is no default pane." >&2; usage; }
[ -n "$UI" ] || { echo "REFUSE: --ui is required. An unsupported UI must never inherit another UI's semantics." >&2; usage; }

# ---------------------------------------------------------------- UI grammars
# One grammar is literal code. A second UI gets its own block, written against real captures of
# every state it can show. External profiles wait for a third, or for the same fix applied twice.
case "$UI" in
  codex)
    G_COMPOSER='Ask Codex to do anything'
    G_PROMPT_ROW='^[[:space:]]*›[[:space:]]*Ask Codex to do anything[[:space:]]*$'
    G_FOOTER='^[[:space:]]*Fast (on|off) [·-] '
    G_OPGLYPH='^›'
    G_QUEUE='Messages to be submitted after next tool call'
    G_BUSY='Working \(|esc to interrupt'
    G_MODAL_ROWS=('No action is required' 'Codex will keep waiting' 'Retry with a faster model' 'Dismiss and keep waiting' 'thinking a bit more about this request')
    G_MODAL_MENU='^[[:space:]]*(›[[:space:]]*)?[123]\.[[:space:]]'
    G_ASK='HALT|Halted|halting|approval|approve|May I|may I|permission|authoriz|confirm|should I|Should I|do you want|Do you want|would you like|shall I|Shall I|let me know|waiting on you|waiting for you|exception request|proceed|OK to |Ok to |okay to |sign off|your call|need a decision|which do you|or should|[Ss]elect one|[Cc]hoose|[Pp]ick one|yes or no'
    G_HOT_DEFAULT='Traceback|FAILED|REFUSE|cyber_policy|Conversation interrupted|rate limit|usage limit|git (commit|reset|clean|checkout|push|add -A)|Divergence|hard-cap'
    ;;
  *) echo "REFUSE: unsupported --ui '$UI'. Supported: codex" >&2; exit 1 ;;
esac

POLL="${PW_POLL:-3}"; STABLE_IDLE=2; MAXFAIL=5; MAXUNKNOWN=4; STATIC_MAX=3
NOREPLY_MAX="${PW_NOREPLY:-60}"; HEARTBEAT="${PW_HEARTBEAT:-1800}"; SCROLL=400
BACKOFF=(0 120 300 600)
TMUX_TIMEOUT="${PW_TMUX_TIMEOUT:-2}"
case "$TMUX_TIMEOUT" in
  ''|*[!0-9]*) echo "REFUSE: PW_TMUX_TIMEOUT must be a positive integer." >&2; exit 64 ;;
esac
[ "$TMUX_TIMEOUT" -ge 1 ] && [ "$TMUX_TIMEOUT" -le 10 ] || { echo "REFUSE: PW_TMUX_TIMEOUT must be an integer from 1 through 10." >&2; exit 64; }
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
[ -n "$TIMEOUT_BIN" ] || { echo "REFUSE: timeout or gtimeout is required to bound tmux requests." >&2; exit 64; }
tmuxq() { "$TIMEOUT_BIN" --signal=TERM --kill-after=1s "$TMUX_TIMEOUT" tmux "$@"; }
timed_out() { case "$1" in 124|137|143) return 0 ;; *) return 1 ;; esac; }

# ---------------------------------------------------------------- pane identity
PANE=$(tmuxq display-message -p -t "$TARGET" '#{pane_id}' 2>/dev/null) || PANE=""
[ -n "$PANE" ] || { echo "REFUSE: '$TARGET' does not resolve to a pane on this tmux server." >&2; exit 1; }
n=$(tmuxq list-panes -a -F '#{pane_id}' 2>/dev/null | grep -cx -- "$PANE")
[ "$n" = "1" ] || { echo "REFUSE: '$TARGET' resolved to $n panes, expected exactly 1." >&2; exit 1; }
[ "$PANE" = "${TMUX_PANE:-}" ] && { echo "REFUSE: refusing to watch my own pane ($PANE)." >&2; exit 1; }
read -r P_DEAD P_CMD P_SESS P_WIN P_PATH <<<"$(tmuxq display-message -p -t "$PANE" \
  '#{pane_dead} #{pane_current_command} #{session_name} #{window_name} #{pane_current_path}' 2>/dev/null)"
[ "${P_DEAD:-1}" = "0" ] || { echo "REFUSE: pane $PANE is dead." >&2; exit 1; }

LOCKROOT="${TMPDIR:-/tmp}/pane-watch-locks"; mkdir -p "$LOCKROOT"
LOCK="$LOCKROOT/$(printf '%s' "$PANE" | tr -d '%')"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ "$REPLACE" = "1" ]; then rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || { echo "REFUSE: cannot take the lock for $PANE." >&2; exit 1; }
  else echo "REFUSE: another watcher already holds $PANE (lock: $LOCK). Use --replace to take over." >&2; exit 1; fi
fi
echo "$$" > "$LOCK/pid"
W=$(mktemp -d "${TMPDIR:-/tmp}/pane-watch.XXXXXX") || { rm -rf "$LOCK"; echo "REFUSE: cannot create a work directory." >&2; exit 1; }
CAP="$W/cap"; LIVE="$W/live"
cleanup() { rm -rf "$W" "$LOCK"; }
# A signal handler that does not exit lets bash RESUME the loop with its workdir deleted.
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

HOTPAT="$W/hot.pat"
if [ -n "$HOTFILE" ]; then
  [ -r "$HOTFILE" ] || { echo "REFUSE: --hot-file '$HOTFILE' is not readable." >&2; exit 1; }
  grep -v '^[[:space:]]*$' "$HOTFILE" > "$HOTPAT"
  [ -s "$HOTPAT" ] || { echo "REFUSE: --hot-file '$HOTFILE' has no patterns." >&2; exit 1; }
  while IFS= read -r pat; do
    printf 'x\n' | grep -E -e "$pat" >/dev/null 2>&1
    [ $? -gt 1 ] && { echo "REFUSE: invalid regex in --hot-file: $pat" >&2; exit 1; }
  done < "$HOTPAT"
else printf '%s\n' "$G_HOT_DEFAULT" > "$HOTPAT"; fi

# ---------------------------------------------------------------- observation
fp() { printf '%s' "$1" | shasum | cut -c1-12; }
read_height() {
  local height_status
  HEIGHT=""
  tmuxq display-message -p -t "$PANE" '#{pane_height}' > "$W/height" 2>/dev/null
  height_status=$?
  [ "$height_status" = 0 ] || return "$height_status"
  IFS= read -r HEIGHT < "$W/height" || true
  case "$HEIGHT" in ''|*[!0-9]*) return 1 ;; esac
}
capture() { tmuxq capture-pane -p -t "$PANE" -S "-$SCROLL" > "$CAP" 2>/dev/null; }

# Sets ST_RAW CI_RAW TURN OPL_RAW SIG NOTHING_YET BOUND HAS_FOOTER WINSIG MODEL.
# Geometry is read from RAW physical rows: command substitution strips trailing blank rows, and
# the live pane puts a blank row between the prompt and the footer.
extract() {
  local nraw i nxt mrows menu lo win body bi nb
  ST_RAW=unknown; CI_RAW=""; TURN=""; OPL_RAW=""; SIG=""; NOTHING_YET=0; BOUND=""; WINSIG=""; MODEL=""
  HAS_FOOTER=$(grep -cE "$G_FOOTER" "$LIVE")
  nraw=$(grep -c '' "$LIVE")
  OPL_RAW=$(grep "$G_OPGLYPH" "$LIVE" | grep -vE "$G_PROMPT_ROW" | tail -1)
  # Identity is set here, before any early return, so a frame we cannot fully parse still has one.
  # Otherwise an unrecognised frame carries no identity and an acknowledgment can never be spent.
  [ -n "$OPL_RAW" ] && SIG=$(fp "op:$OPL_RAW")

  # The live prompt is a full row, and the footer is its next NON-BLANK row.
  for i in $(grep -nE "$G_PROMPT_ROW" "$LIVE" | cut -d: -f1 | sort -rn); do
    nxt=$(tail -n +$((i+1)) "$LIVE" | grep -n -m1 '[^[:space:]]' | cut -d: -f1)
    [ -z "$nxt" ] && continue
    if tail -n +$((i+1)) "$LIVE" | sed -n "${nxt}p" | grep -qE "$G_FOOTER"; then
      CI_RAW="$i"; FOOTER_ROW=$((i+nxt)); break
    fi
  done

  if [ -z "$CI_RAW" ]; then
    # A modal is a STRUCTURE: no prompt, no footer, a numbered menu, and marker rows at the bottom.
    mrows=$( { for m in "${G_MODAL_ROWS[@]}"; do grep -nF "$m" "$LIVE"; done; } 2>/dev/null \
             | cut -d: -f1 | sort -un | awk -v n="$nraw" '$1 > n-12' | grep -c '^' )
    menu=$(grep -cE "$G_MODAL_MENU" "$LIVE")
    [ "$mrows" -ge 2 ] && [ "$menu" -ge 2 ] && [ "$HAS_FOOTER" -eq 0 ] && ST_RAW=modal
    return
  fi

  MODEL=$(sed -n "${FOOTER_ROW}p" "$LIVE" | awk -F' [·-] ' '{gsub(/^[ \t]+/,"",$1); print $1", "$2}')
  lo=$((CI_RAW-2)); [ "$lo" -lt 1 ] && lo=1
  win=$(sed -n "${lo},${CI_RAW}p" "$LIVE" | grep -v '^[[:space:]]*$' | tail -2)
  WINSIG=$(fp "$win")
  ST_RAW=idle
  printf '%s\n' "$win" | grep -qF "$G_QUEUE" && ST_RAW=queued
  [ "$ST_RAW" = "idle" ] && printf '%s\n' "$win" | grep -qE "$G_BUSY" && ST_RAW=busy

  body=$(head -n $((CI_RAW-1)) "$LIVE" | grep -v '^[[:space:]]*$')
  nb=$(printf '%s\n' "$body" | grep -c '^')
  bi=$(printf '%s\n' "$body" | grep -n "$G_OPGLYPH" | tail -1 | cut -d: -f1)
  if [ -n "$bi" ]; then
    TURN=$(printf '%s\n' "$body" | tail -n +$((bi+1)))
    [ "$bi" -eq "$nb" ] && NOTHING_YET=1
  else
    TURN=$(printf '%s\n' "$body" | tail -40)
    BOUND="no operator turn boundary on screen; showing the last 40 rows, the request may be older than this"
  fi
  TURN=$(printf '%s\n' "$TURN" | grep -vE '^[[:space:]]*─+$')

  # Identity is the operator row (set above), not the rendered text: the agent re-renders its
  # transcript into recaps, changing the text without changing which message it is answering.
  # Rendered text is alert CONTENT. With the boundary scrolled away there is no operator row, so
  # fall back to the text hash rather than letting distinct turns share one identity.
  [ -z "$OPL_RAW" ] && SIG=$(fp "txt:$TURN")
}

# ---------------------------------------------------------------- preflight
read_height
initial_height_rc=$?
H="$HEIGHT"
[ "$initial_height_rc" = 0 ] && [ -n "$H" ] || { echo "REFUSE: cannot read pane geometry for $PANE." >&2; exit 1; }
tries=0
while :; do
  read_height; h0_rc=$?; H0="$HEIGHT"
  [ "$h0_rc" = 0 ] || { echo "REFUSE: cannot read pane geometry for $PANE." >&2; exit 1; }
  capture || { echo "REFUSE: cannot capture $PANE." >&2; exit 1; }
  read_height; h1_rc=$?; H1="$HEIGHT"
  [ "$h1_rc" = 0 ] || { echo "REFUSE: cannot read pane geometry for $PANE." >&2; exit 1; }
  [ "$H0" = "$H1" ] && [ -n "$H0" ] && break
  tries=$((tries+1)); [ "$tries" -ge 3 ] && { echo "REFUSE: pane geometry will not hold still (${H0}r vs ${H1}r)." >&2; exit 1; }
  sleep 1
done
H="$H0"; PH="$H"; tail -n "$H" "$CAP" > "$LIVE"
extract
case "$ST_RAW" in
  idle|busy|queued|modal) : ;;
  *) echo "REFUSE: the '$UI' grammar does not recognise pane $PANE ($P_SESS:$P_WIN, $P_CMD)." >&2
     echo "        No prompt/footer structure and no modal structure in the live region." >&2
     echo "        Refusing to arm rather than watching a pane I cannot read." >&2
     exit 1 ;;
esac

fails=0; unknowns=0; idle_run=0; winstatic=0; prev_winsig="$WINSIG"; hot_turn=""; hot_seen=""
noreply_since=0; noreply_sig=""; acked=""; alerts=0; next_alert=0; alert_sig=""; last_sig="$SIG"
warned=""; dgw=""; reseed_ack=0; base_model="$MODEL"; last_hb=$(date +%s); last_valid=$(date +%s)
[ "$ACK_CURRENT" = "1" ] && acked="$SIG"

echo "ARMED $UI on $PANE ($P_SESS:$P_WIN, $P_CMD, $P_PATH)"
echo "      live=${H}r state=$ST_RAW model=${MODEL:-none} hot=$([ -n "$HOTFILE" ] && echo "$HOTFILE" || echo built-in) startup-ack=$ACK_CURRENT"

coverage_lost() {
  echo "=========================================================="
  echo ">>>>>>>>>>  WATCH COVERAGE LOST  <<<<<<<<<<"
  echo "$1"
  echo "Pane $PANE ($P_SESS:$P_WIN) is NO LONGER BEING WATCHED."
  echo "Nothing will alert you until this is re-armed."
  echo "=========================================================="
  exit "$2"
}

request_failed() {
  failed_rc=$1
  failed_label=$2
  fails=$((fails+1)); idle_run=0; winstatic=0; prev_winsig=""
  timed_out "$failed_rc" && coverage_lost "A tmux $failed_label request reached its ${TMUX_TIMEOUT}s bound; stopping rather than accumulating blocked clients." 3
  [ "$fails" -ge "$MAXFAIL" ] && coverage_lost "$MAXFAIL consecutive tmux request failures. The pane or the tmux server is gone." 3
}

while :; do
  sleep "$POLL"
  now=$(date +%s)

  read_height
  hpre_rc=$?
  Hpre="$HEIGHT"
  if [ "$hpre_rc" != 0 ]; then
    request_failed "$hpre_rc" 'geometry'
    continue
  fi
  if capture; then
    fails=0
  else
    capture_rc=$?
    request_failed "$capture_rc" 'capture'
    continue
  fi
  read_height
  hpost_rc=$?
  Hpost="$HEIGHT"
  if [ "$hpost_rc" != 0 ]; then
    request_failed "$hpost_rc" 'geometry'
    continue
  fi
  if [ -n "$Hpre" ] && [ -n "$Hpost" ] && [ "$Hpre" != "$Hpost" ]; then
    echo "NOTICE: pane resized during the capture (${Hpre}r -> ${Hpost}r); discarding this observation"
    PH="$Hpost"; idle_run=0; winstatic=0; prev_winsig=""; [ -n "$acked" ] && reseed_ack=1; continue
  fi
  H="${Hpre:-$PH}"
  if [ "$H" != "$PH" ]; then
    echo "NOTICE: pane resized ${PH}r -> ${H}r; state unreliable for one cycle"
    PH="$H"; idle_run=0; winstatic=0; prev_winsig=""; [ -n "$acked" ] && reseed_ack=1
  fi
  tail -n "$H" "$CAP" > "$LIVE"

  extract
  if [ -n "$WINSIG" ] && [ "$WINSIG" = "$prev_winsig" ]; then winstatic=$((winstatic+1)); else winstatic=0; dgw=""; fi
  prev_winsig="$WINSIG"

  # A resize changes the visible slice, not the conversation.
  if [ "$reseed_ack" = "1" ] && [ -n "$SIG" ]; then acked="$SIG"; reseed_ack=0; fi

  ST="$ST_RAW"; forced=0
  if [ "$ST" != "idle" ] && [ "$ST" != "unknown" ] && [ "$ST" != "modal" ] && [ "$winstatic" -ge "$STATIC_MAX" ]; then
    ST=idle; forced=1
    [ "$dgw" != "$WINSIG" ] && { echo "NOTICE: the status row claims work but has not moved in $((winstatic*POLL))s; disbelieving it"; dgw="$WINSIG"; }
  fi

  # Acknowledgment is spent by observed activity or by a changed turn, before any early return.
  if [ -n "$acked" ]; then
    { [ "$ST" = "busy" ] || [ "$ST" = "queued" ]; } && acked=""
    [ -n "$SIG" ] && [ "$SIG" != "$acked" ] && acked=""
  fi

  if [ -n "$MODEL" ]; then
    if [ -z "$base_model" ]; then base_model="$MODEL"
    elif [ "$MODEL" != "$base_model" ]; then
      echo "*** MODEL/CONFIG CHANGED: [$base_model] -> [$MODEL] :: HALT AND SURFACE ***"; base_model="$MODEL"
    fi
  fi

  if [ "$ST" = "modal" ]; then
    unknowns=0; idle_run=0; last_valid=$now
    [ "$warned" != "modal" ] && { echo "NOTICE: the agent is showing a service modal. It states no action is required and it will keep waiting. Not idle, not dead."; warned="modal"; }
    continue
  fi
  [ "$warned" = "modal" ] && warned=""

  if [ "$ST" = "unknown" ]; then
    unknowns=$((unknowns+1)); idle_run=0
    [ "$unknowns" -ge "$MAXUNKNOWN" ] && coverage_lost "The '$UI' grammar stopped recognising this pane for $((unknowns*POLL))s. It may have exited, been replaced, or be rendering something this grammar cannot read." 2
    continue
  fi
  unknowns=0; last_valid=$now

  [ -n "$BOUND" ] && [ "$BOUND" != "$warned" ] && { echo "NOTICE: $BOUND"; warned="$BOUND"; }
  [ "$SIG" != "$last_sig" ] && { idle_run=0; alerts=0; next_alert=0; alert_sig=""; noreply_since=0; noreply_sig=""; last_sig="$SIG"; }

  [ "$OPL_RAW" != "$hot_turn" ] && { hot_turn="$OPL_RAW"; hot_seen=""; }
  hot=$(printf '%s\n' "$TURN" | grep -hoE -f "$HOTPAT" 2>/dev/null | tail -1)
  if [ -n "$hot" ] && ! printf '%s\n' "$hot_seen" | grep -qxF -- "$hot"; then
    echo "HOT: $(printf '%s' "$hot" | sed 's/^[[:space:]]*//' | cut -c1-200)"; hot_seen="$hot_seen
$hot"
  fi

  if [ "$ST" = "idle" ]; then idle_run=$((idle_run+1)); else idle_run=0; alerts=0; next_alert=0; alert_sig=""; fi

  nothing_yet="$NOTHING_YET"
  if [ "$nothing_yet" -eq 1 ] && [ "$ST" = "idle" ]; then
    [ "$noreply_sig" != "$SIG" ] && { noreply_since=$now; noreply_sig="$SIG"; }
    if [ $((now - noreply_since)) -ge "$NOREPLY_MAX" ]; then
      nothing_yet=0; BOUND="no reply since your last input for $((now - noreply_since))s; either it never arrived or the turn boundary is wrong"
    fi
  fi

  if [ "$idle_run" -ge "$STABLE_IDLE" ] && [ "$nothing_yet" -eq 0 ] && [ "$SIG" != "$acked" ]; then
    [ "$SIG" != "$alert_sig" ] && { alerts=0; next_alert=0; alert_sig="$SIG"; }
    if [ "$now" -ge "$next_alert" ]; then
      q=$(printf '%s\n' "$TURN" | grep -E '\?[[:space:]]*$' | tail -1 | sed 's/^[[:space:]]*//' | cut -c1-200)
      a=$(printf '%s\n' "$TURN" | grep -hoE ".{0,80}($G_ASK).{0,80}" | tail -1 | sed 's/^[[:space:]]*//' | cut -c1-200)
      t2=$(printf '%s\n' "$TURN" | grep -v '^[[:space:]]*$' | tail -2 | sed 's/^[[:space:]]*//' | cut -c1-160 | paste -sd'|' -)
      [ -z "$t2" ] && t2="(turn text could not be extracted; treat as an unread wait)"
      if [ -n "$q" ]; then why="waiting on a DECISION from you"
      elif [ -n "$a" ]; then why="idle, and its last turn reads like a request"
      else why="idle with a completed, unacknowledged turn"; fi
      alerts=$((alerts+1)); b=${BACKOFF[$alerts]:-600}; next_alert=$((now+b))
      echo "=========================================================="
      echo ">>>>>>>>>>  OPERATOR ACTION NEEDED  <<<<<<<<<<"
      echo "$UI on $PANE ($P_SESS:$P_WIN) is $why. Nothing moves until you answer. [alert #$alerts]"
      [ -n "$q" ] && echo "question: $q"
      [ -n "$a" ] && [ "$a" != "$q" ] && echo "trigger:  $a"
      echo "last:     $t2"
      [ -n "$BOUND" ] && echo "WARNING: $BOUND"
      [ "$forced" = "1" ] && echo "WARNING: this idle was INFERRED; the status row claimed work but had not moved in $((winstatic*POLL))s"
      echo "=========================================================="
    fi
  fi

  if [ $((now - last_hb)) -ge "$HEARTBEAT" ]; then
    echo "HEALTH: coverage=valid pane=$PANE ui=$UI state=$ST last_valid=$((now-last_valid))s ago"; last_hb=$now
  fi
done
