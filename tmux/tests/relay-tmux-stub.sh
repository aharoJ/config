#!/usr/bin/env bash
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
    printf '%s\n' "$RELAY_TEST_CAPTURE"
    ;;
  display-message)
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
  if-shell)
    case "${RELAY_TEST_RECEIPT_MODE:-delivered}" in
      copy)
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
      *__CODEX_SEND_TO_DELIVERED__*) printf '%s\n' '__CODEX_SEND_TO_DELIVERED__' ;;
      *__CODEX_SEND_DELIVERED__*) printf '%s\n' '__CODEX_SEND_DELIVERED__' ;;
      *__CC_MSG_DELIVERED__*) printf '%s\n' '__CC_MSG_DELIVERED__' ;;
      *) exit 1 ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
