#!/usr/bin/env bash
# onboard-family — one-time nabla setup so future surfaces deploy without sudo.
#
# Adds:
#   - /etc/caddy/conf.d/        owned by uprootiny (drop snippets here)
#   - import /etc/caddy/conf.d/*.caddyfile  in /etc/caddy/Caddyfile
#   - sudoers rule allowing uprootiny to reload caddy without password
#
# Idempotent. Run from local mac, prompts for sudo on nabla.
set -euo pipefail

NABLA_SSH=(ssh -o RemoteCommand=none -t nabla)

"${NABLA_SSH[@]}" 'set -e

  echo "[1/4] /etc/caddy/conf.d ownership"
  if [[ ! -d /etc/caddy/conf.d ]]; then
    sudo mkdir -p /etc/caddy/conf.d
  fi
  sudo chown uprootiny:uprootiny /etc/caddy/conf.d
  ls -la /etc/caddy/conf.d/.. | awk "/conf.d/"

  echo "[2/4] import line in /etc/caddy/Caddyfile"
  if sudo grep -qF "import /etc/caddy/conf.d/" /etc/caddy/Caddyfile; then
    echo "  already present"
  else
    # Append at top so site blocks below it can use globals from snippets too.
    TMP="$(sudo mktemp)"
    {
      echo "import /etc/caddy/conf.d/*.caddyfile"
      echo
      sudo cat /etc/caddy/Caddyfile
    } | sudo tee "$TMP" >/dev/null
    sudo install -m 644 -o root -g root "$TMP" /etc/caddy/Caddyfile
    sudo rm -f "$TMP"
    echo "  added"
  fi

  echo "[3/4] sudoers rule for caddy reload (passwordless)"
  SUDOERS=/etc/sudoers.d/uprootiny-caddy
  if [[ ! -f /etc/sudoers.d/uprootiny-caddy ]]; then
    echo "uprootiny ALL=(root) NOPASSWD: /bin/systemctl reload caddy, /bin/systemctl restart caddy, /usr/bin/caddy validate *" | sudo tee "$SUDOERS" >/dev/null
    sudo chmod 440 "$SUDOERS"
    sudo visudo -cf "$SUDOERS" >/dev/null && echo "  installed"
  else
    echo "  already present"
  fi

  echo "[4/4] validate + reload caddy"
  sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 | tail -3
  sudo systemctl reload caddy
  systemctl is-active caddy
'

echo
echo "Done. Future surfaces only need:"
echo "  1) drop a *.caddyfile in nabla:/etc/caddy/conf.d/"
echo "  2) ssh nabla sudo systemctl reload caddy   (no password — sudoers rule)"
echo "  3) (optional) ~/.config/systemd/user/<name>.service  — user systemd, no sudo"
