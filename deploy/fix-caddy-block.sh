#!/usr/bin/env bash
# fix-caddy-block — remove the broken twelve.solvulator.com block
# (with the bad log path) from /etc/caddy/Caddyfile and re-append the
# corrected snippet, then reload caddy. Requires interactive sudo.
set -euo pipefail

NABLA_SSH=(ssh -o RemoteCommand=none -t nabla)

echo "[1/2] strip existing twelve block, append corrected, validate"
"${NABLA_SSH[@]}" 'set -e
  CF=/etc/caddy/Caddyfile

  # Show current tail so we know what we are operating on
  echo "--- before (tail of Caddyfile) ---"
  sudo tail -10 "$CF"

  # Remove any existing twelve.solvulator.com { ... } block.
  # Robust: capture between the opening header and the matching closing brace.
  TMP="$(mktemp)"
  sudo awk "
    BEGIN { skipping = 0; depth = 0 }
    /^twelve\\.solvulator\\.com[[:space:]]*\\{/ { skipping = 1; depth = 1; next }
    skipping {
      n_open  = gsub(/\\{/, \"&\")
      n_close = gsub(/\\}/, \"&\")
      depth += n_open - n_close
      if (depth <= 0) { skipping = 0 }
      next
    }
    { print }
  " "$CF" | sudo tee "$TMP" >/dev/null

  # Trim trailing blank lines, then append fresh snippet.
  sudo sh -c "sed -e :a -e '/^\\s*\$/{\$d;N;ba' -e '}' \"$TMP\" > \"$TMP.clean\""
  sudo sh -c "cat \"$TMP.clean\" /home/uprootiny/twelve/deploy/Caddyfile.snippet > $CF.new"
  sudo install -m 644 -o root -g root "$CF.new" "$CF"
  sudo rm -f "$TMP" "$TMP.clean" "$CF.new"

  echo "--- after (tail of Caddyfile) ---"
  sudo tail -10 "$CF"
  echo "--- validate ---"
  sudo caddy validate --config "$CF" --adapter caddyfile 2>&1 | tail -5
'

echo "[2/2] reload caddy"
"${NABLA_SSH[@]}" 'set -e
  sudo systemctl reload caddy
  sleep 1
  systemctl is-active caddy
  echo "--- twelve service ---"
  systemctl is-active twelve
  echo "--- loopback through caddy ---"
  curl -sS -o /dev/null -w "  https://localhost (Host: twelve.solvulator.com): %{http_code}\n" \
    -k -H "Host: twelve.solvulator.com" https://127.0.0.1/healthz || true
'

echo
echo "Done. Now try from your machine:"
echo "  curl -sS https://twelve.solvulator.com/healthz"
