#!/usr/bin/env bash
# Finish deployment of twelve on nabla — interactive sudo required.
# Run from the local mac. Will ssh -t nabla to give you a sudo prompt.
set -euo pipefail

NABLA_SSH=(ssh -o RemoteCommand=none -t nabla)

echo "[1/3] kill nohup-started twelve so systemd can bind :47312"
"${NABLA_SSH[@]/-t/-o BatchMode=yes}" '
  if [[ -f /home/uprootiny/twelve/.twelve.pid ]]; then
    kill "$(cat /home/uprootiny/twelve/.twelve.pid)" 2>/dev/null || true
    rm -f /home/uprootiny/twelve/.twelve.pid
    echo "  killed nohup pid"
  else
    echo "  no nohup pid — fine"
  fi
'

echo "[2/3] install + enable + start systemd unit"
"${NABLA_SSH[@]}" 'set -e
  sudo install -m 644 /home/uprootiny/twelve/deploy/twelve.service /etc/systemd/system/twelve.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now twelve.service
  sleep 1
  sudo systemctl status twelve.service --no-pager | head -8
  echo "  loopback healthz:"
  curl -sS -o /dev/null -w "    %{http_code}\n" http://127.0.0.1:47312/healthz
'

echo "[3/3] append Caddyfile snippet, validate, reload caddy"
"${NABLA_SSH[@]}" 'set -e
  if grep -q "twelve.solvulator.com" /etc/caddy/Caddyfile; then
    echo "  twelve.solvulator.com block already present in Caddyfile — skipping append"
  else
    sudo tee -a /etc/caddy/Caddyfile < /home/uprootiny/twelve/deploy/Caddyfile.snippet >/dev/null
    echo "  appended block"
  fi
  sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1 | tail -5
  sudo systemctl reload caddy
  echo "  caddy reloaded"
'

echo
echo "Done. Next step (DNS):"
echo "  add A record  twelve.solvulator.com  ->  35.252.20.194  at your DNS provider"
echo "  then:  curl -sS https://twelve.solvulator.com/healthz"
