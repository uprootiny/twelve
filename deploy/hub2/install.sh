#!/usr/bin/env bash
# Install twelve on hub2 + onboard family pattern (one-time).
#
# After this runs:
#   - https://twelve.raindesk.dev/  serves through caddy
#   - http://149.102.137.139:47312/ serves direct
#   - twelve survives reboot via user-level systemd
#   - /etc/caddy/conf.d/ writable by uprootiny — drop new snippets without sudo
#   - sudo systemctl reload caddy is NOPASSWD for uprootiny
#   - Future *.raindesk.dev surfaces deploy without any sudo at all
#
# One interactive sudo password prompt total. Idempotent.

set -euo pipefail
HUB2_SSH=(ssh -o RemoteCommand=none -t hub2)

echo "[1/5] /etc/caddy/conf.d/ + import line in /etc/caddy/Caddyfile"
"${HUB2_SSH[@]}" 'set -e
  if [[ ! -d /etc/caddy/conf.d ]]; then sudo mkdir -p /etc/caddy/conf.d; fi
  sudo chown uprootiny:uprootiny /etc/caddy/conf.d
  sudo chmod 755 /etc/caddy/conf.d

  if sudo grep -qF "import /etc/caddy/conf.d/" /etc/caddy/Caddyfile; then
    echo "  import line already present"
  else
    TMP="$(sudo mktemp)"
    {
      echo "import /etc/caddy/conf.d/*.caddyfile"
      echo
      sudo cat /etc/caddy/Caddyfile
    } | sudo tee "$TMP" >/dev/null
    sudo install -m 644 -o root -g root "$TMP" /etc/caddy/Caddyfile
    sudo rm -f "$TMP"
    echo "  import line added"
  fi
'

echo "[2/5] sudoers: NOPASSWD for caddy reload/restart/validate"
"${HUB2_SSH[@]}" 'set -e
  SUDOERS=/etc/sudoers.d/uprootiny-caddy
  if [[ ! -f "$SUDOERS" ]]; then
    echo "uprootiny ALL=(root) NOPASSWD: /bin/systemctl reload caddy, /bin/systemctl restart caddy, /usr/bin/caddy validate *, /usr/bin/caddy fmt *" | sudo tee "$SUDOERS" >/dev/null
    sudo chmod 440 "$SUDOERS"
    sudo visudo -cf "$SUDOERS" >/dev/null && echo "  sudoers rule installed"
  else
    echo "  sudoers rule already present"
  fi
'

echo "[3/5] drop twelve.raindesk.dev snippet into conf.d (no sudo)"
"${HUB2_SSH[@]/-t/-o BatchMode=yes}" '
  install -m 644 /home/uprootiny/twelve/deploy/hub2/Caddyfile.snippet /etc/caddy/conf.d/twelve.caddyfile
  ls -la /etc/caddy/conf.d/
  caddy fmt --overwrite /etc/caddy/conf.d/twelve.caddyfile 2>&1 | head -1 || true
'

echo "[4/5] validate + reload caddy"
"${HUB2_SSH[@]/-t/-o BatchMode=yes}" '
  sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 | tail -3
  sudo systemctl reload caddy
  systemctl is-active caddy
'

echo "[5/5] user-level systemd unit, hand off from nohup"
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

  if [[ -f /home/uprootiny/twelve/.twelve.pid ]]; then
    kill "$(cat /home/uprootiny/twelve/.twelve.pid)" 2>/dev/null || true
    rm -f /home/uprootiny/twelve/.twelve.pid
  fi

  systemctl --user daemon-reload
  systemctl --user enable --now twelve.service
  loginctl enable-linger uprootiny 2>/dev/null || true
  sleep 0.5
  systemctl --user is-active twelve
  echo "  loopback healthz: $(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:47312/healthz)"
'

echo
echo "Done. Live URLs:"
echo "  https://twelve.raindesk.dev/        (browser-friendly)"
echo "  http://149.102.137.139:47312/       (direct port)"
echo
echo "From now on, a new surface = drop a *.caddyfile in hub2:/etc/caddy/conf.d/"
echo "and run 'ssh hub2 sudo systemctl reload caddy' (passwordless, sudoers rule)."
