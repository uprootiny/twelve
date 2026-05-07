#!/usr/bin/env bash
# twelve — idempotent start/stop for the workspace walker.
# Usage: ./twelve.sh [up|down|status|open]
#
# Env:
#   TWELVE_PORT  bind port (default 9412 for local dev; 47312 in production)
#   TWELVE_BIND  bind address (default 127.0.0.1)
#   TWELVE_ROOT  workspace to walk (default: parent of this script)
set -euo pipefail
cd "$(dirname "$0")"

PORT="${TWELVE_PORT:-9412}"
BIND="${TWELVE_BIND:-127.0.0.1}"
PIDFILE=".twelve.pid"
LOGFILE=".twelve.log"

cmd="${1:-up}"

is_running() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

port_listening() {
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

case "$cmd" in
  up)
    if is_running; then
      echo "[twelve] already up (pid $(cat "$PIDFILE")) → http://$BIND:$PORT/"
      exit 0
    fi
    if port_listening; then
      echo "[twelve] port $PORT busy — not mine. Resolve before retry."
      lsof -nP -iTCP:"$PORT" -sTCP:LISTEN
      exit 1
    fi
    TWELVE_PORT="$PORT" TWELVE_BIND="$BIND" nohup python3 twelve.py >>"$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.4
    if is_running; then
      echo "[twelve] up · pid $(cat "$PIDFILE") · http://$BIND:$PORT/"
      echo "[twelve] log: tail -f $LOGFILE"
    else
      echo "[twelve] failed to start — see $LOGFILE"
      tail -20 "$LOGFILE" || true
      rm -f "$PIDFILE"
      exit 1
    fi
    ;;
  down)
    if is_running; then
      pid="$(cat "$PIDFILE")"
      kill "$pid" 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "[twelve] stopped pid $pid"
    else
      rm -f "$PIDFILE"
      echo "[twelve] not running"
    fi
    ;;
  status)
    if is_running; then
      echo "[twelve] up · pid $(cat "$PIDFILE") · http://$BIND:$PORT/"
    else
      echo "[twelve] down"
      exit 1
    fi
    ;;
  open)
    "$0" up
    if command -v open >/dev/null 2>&1; then
      open "http://$BIND:$PORT/"
    else
      echo "open http://$BIND:$PORT/ in your browser"
    fi
    ;;
  *)
    echo "usage: $0 [up|down|status|open]" >&2
    exit 2
    ;;
esac
