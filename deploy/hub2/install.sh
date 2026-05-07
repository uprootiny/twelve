#!/usr/bin/env bash
# Install twelve on hub2: Caddyfile entry + (optional) systemd unit.
# Run from local mac. Interactive sudo on hub2 (hub2 needs password
# but no NOPASSWD restrictions besides wireguard).
set -euo pipefail
HUB2_SSH=(ssh -o RemoteCommand=none -t hub2)

echo "[1/3] strip + append twelve.raindesk.dev block in /etc/caddy/Caddyfile"
"${HUB2_SSH[@]}" 'set -e
  CF=/etc/caddy/Caddyfile

  # Idempotent: drop any existing block first
  TMP="$(sudo mktemp)"
  sudo awk "
    BEGIN { skipping = 0; depth = 0 }
    /^twelve\\.raindesk\\.dev[[:space:]]*\\{/ { skipping = 1; depth = 1; next }
    skipping {
      n_open  = gsub(/\\{/, \"&\")
      n_close = gsub(/\\}/, \"&\")
      depth += n_open - n_close
      if (depth <= 0) { skipping = 0 }
      next
    }
    { print }
  " "$CF" | sudo tee "$TMP" >/dev/null

  CFNEW="$(sudo mktemp)"
  sudo bash -c "cat \"$TMP\" /home/uprootiny/twelve/deploy/hub2/Caddyfile.snippet > \"$CFNEW\""
  sudo install -m 644 -o root -g root "$CFNEW" "$CF"
  sudo rm -f "$TMP" "$CFNEW"

  echo "  --- new tail ---"
  sudo tail -6 "$CF"
'

echo "[2/3] validate + reload"
"${HUB2_SSH[@]}" 'set -e
  sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 | tail -3
  sudo systemctl reload caddy
  systemctl is-active caddy
'

echo "[3/3] make twelve survive reboot — install user-level systemd unit"
"${HUB2_SSH[@]/-t/-o BatchMode=yes}" '
  mkdir -p ~/.config/systemd/user
  cat > ~/.config/systemd/user/twelve.service <<UNIT
[Unit]
Description=twelve — workspace walker (user-level)
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/home/uprootiny/twelve
Environment=TWELVE_PORT=47312
Environment=TWELVE_BIND=0.0.0.0
Environment=TWELVE_ROOT=/home/uprootiny
Environment=TWELVE_HUB2=hub2
ExecStart=/usr/bin/python3 /home/uprootiny/twelve/twelve.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
UNIT

  # Stop the nohup, hand off to systemd --user
  if [[ -f /home/uprootiny/twelve/.twelve.pid ]]; then
    kill "$(cat /home/uprootiny/twelve/.twelve.pid)" 2>/dev/null || true
    rm -f /home/uprootiny/twelve/.twelve.pid
  fi

  systemctl --user daemon-reload
  systemctl --user enable --now twelve.service 2>&1 | head -3
  sleep 0.5
  systemctl --user is-active twelve

  # Lingering: keep user services alive after logout
  loginctl enable-linger uprootiny 2>&1 | head -1 || true

  echo "  loopback healthz:"
  curl -sS -o /dev/null -w "    %{http_code}\n" http://127.0.0.1:47312/healthz
'

echo
echo "Done. Browser-friendly URL (cert auto-issues on first request):"
echo "  https://twelve.raindesk.dev/"
echo "Direct port URL:"
echo "  http://149.102.137.139:47312/"
