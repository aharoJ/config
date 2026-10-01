#!/usr/bin/env bash
# path: ~/.config/tmux/tests/relay-tmux-stub.sh
# description: Emulate relay routing, bracketed payload delivery, and composer captures.
# patched: model structured footers and receiver process identity with landed text verification
# date: 2026-10-01
set -euo pipefail

: "${RELAY_TEST_CAPTURE:?}"
: "${RELAY_TEST_LOG:?}"
: "${RELAY_TEST_PANES:?}"

printf '%s\n' "${1:-}" >> "$RELAY_TEST_LOG"

if [ "${RELAY_TEST_FAIL_COMMAND:-}" = "${1:-}" ]; then
  exit "${RELAY_TEST_FAIL_STATUS:-1}"
fi

case "${1:-}" in
  list-panes)
    printf '%s\n' "$RELAY_TEST_PANES"
    ;;
  capture-pane)
    if [ -s "$RELAY_TEST_LOG.payload" ]; then
      payload="$(cat "$RELAY_TEST_LOG.payload")"
      if [[ "$RELAY_TEST_PANES" = *claude* ]]; then
        printf '────────────────────\n❯ %s\n────────────────────\n' "$payload"
      else
        printf '› %s\n\033[49m  Fast off · test · Context 0%% used\n' "$payload"
      fi
    else
      printf '%s\n' "$RELAY_TEST_CAPTURE"
    fi
    ;;
  display-message)
    format="${!#}"
    if [[ "$format" = '#{pane_width}:#{pane_height}:#{pane_dead}:#{session_name}:#{window_name}:#{pane_pid}:#{pane_current_command}' ]]; then
      printf '192:51:0:relaytest:%s:100:%s\n' "$(awk 'NR == 1 {print $3}' <<< "$RELAY_TEST_PANES")" "$(awk 'NR == 1 {print $4}' <<< "$RELAY_TEST_PANES")"
      exit 0
    fi
    if [ -s "$RELAY_TEST_LOG.payload" ]; then
      column=$(($(wc -c < "$RELAY_TEST_LOG.payload") + 2))
      row=0
      [[ "$RELAY_TEST_PANES" = *claude* ]] && row=1
      suffix=
      [[ "$format" = *pane_width* ]] && suffix=":192:51:100:$(awk 'NR == 1 {print $4}' <<< "$RELAY_TEST_PANES")"
      printf '0:%s:%s:0:relaytest:%s%s\n' "$column" "$row" "$(awk 'NR == 1 {print $3}' <<< "$RELAY_TEST_PANES")" "$suffix"
      exit 0
    fi
    state_count_file="${RELAY_TEST_STATE_COUNT_FILE:-${RELAY_TEST_LOG}.state-count}"
    state_count=0
    [ -f "$state_count_file" ] && state_count="$(< "$state_count_file")"
    state_count=$((state_count + 1))
    printf '%s\n' "$state_count" > "$state_count_file"
    if [ "$state_count" -eq 1 ] && [ -n "${RELAY_TEST_STATE_BEFORE:-}" ]; then
      printf '%s\n' "$RELAY_TEST_STATE_BEFORE"
    elif [ "$state_count" -gt 1 ] && [ -n "${RELAY_TEST_STATE_AFTER:-}" ]; then
      printf '%s\n' "$RELAY_TEST_STATE_AFTER"
    else
      printf '%s\n' "${RELAY_TEST_STATE:-${RELAY_TEST_PANE_MODE:-0}:2:0}"
    fi
    ;;
  if-shell|source-file)
    if [ "$1" = source-file ]; then
      set -- if-shell "$(cat "$2")"
    fi
    if [[ "$*" = *paste-buffer* ]]; then
      cat "$RELAY_TEST_LOG.buffer" >> "$RELAY_TEST_LOG.payload"
    fi
    case "${RELAY_TEST_RECEIPT_MODE:-delivered}" in
      copy)
        if [[ "$*" = *__RELAY_REFUSED__* ]]; then
          printf '__RELAY_REFUSED__:1:0:relaytest:%s\n' "$(awk 'NR == 1 {print $3}' <<< "$RELAY_TEST_PANES")"
          exit 0
        fi
        case " $* " in
          *__CODEX_SEND_TO_REFUSED_COPY_MODE__*) printf '%s\n' '__CODEX_SEND_TO_REFUSED_COPY_MODE__' ;;
          *__CODEX_SEND_REFUSED_COPY_MODE__*) printf '%s\n' '__CODEX_SEND_REFUSED_COPY_MODE__' ;;
          *__CC_MSG_REFUSED_COPY_MODE__*) printf '%s\n' '__CC_MSG_REFUSED_COPY_MODE__' ;;
          *) exit 1 ;;
        esac
        exit 0
        ;;
      unknown)
        printf '%s\n' '__RELAY_TEST_UNKNOWN_RECEIPT__'
        exit 0
        ;;
    esac
    case " $* " in
      *__RELAY_DELIVERED__*) printf '%s\n' '__RELAY_DELIVERED__' ;;
      *__CODEX_SEND_TO_DELIVERED__*) printf '%s\n' '__CODEX_SEND_TO_DELIVERED__' ;;
      *__CODEX_SEND_DELIVERED__*) printf '%s\n' '__CODEX_SEND_DELIVERED__' ;;
      *__CC_MSG_DELIVERED__*) printf '%s\n' '__CC_MSG_DELIVERED__' ;;
      *) exit 1 ;;
    esac
    ;;
  load-buffer)
    cat "${!#}" > "$RELAY_TEST_LOG.buffer"
    ;;
  *)
    exit 0
    ;;
esac
