# Deploying twelve to nabla

Target: **twelve.solvulator.com → 127.0.0.1:47312** on nabla. Fresh
high port, novel subdomain, does not displace `cockpit.solvulator.com`
(:9090, currently live) or `solvulator.com` (:9800).

## What gets installed

| target                                       | source                          |
| -------------------------------------------- | ------------------------------- |
| `nabla:/home/uprootiny/twelve/`              | rsync of repo (no `.git`)       |
| `nabla:/etc/systemd/system/twelve.service`   | `deploy/twelve.service`         |
| append to `nabla:/etc/caddy/Caddyfile`       | `deploy/Caddyfile.snippet`      |

## Steps (run from this directory on local mac)

```sh
# 1. Sync code
rsync -av --exclude='.git' --exclude='.twelve.*' \
      --exclude='__pycache__' \
      ../ nabla:/home/uprootiny/twelve/

# 2. Install systemd unit (interactive sudo on nabla)
ssh -t nabla 'sudo install -m 644 \
              /home/uprootiny/twelve/deploy/twelve.service \
              /etc/systemd/system/twelve.service && \
              sudo systemctl daemon-reload && \
              sudo systemctl enable --now twelve.service && \
              sudo systemctl status twelve.service --no-pager | head -8'

# 3. Smoke test (loopback)
ssh nabla 'curl -sS http://127.0.0.1:47312/healthz'

# 4. Append caddy snippet (interactive sudo)
ssh -t nabla 'sudo tee -a /etc/caddy/Caddyfile < \
              /home/uprootiny/twelve/deploy/Caddyfile.snippet >/dev/null && \
              sudo caddy validate --config /etc/caddy/Caddyfile && \
              sudo systemctl reload caddy'

# 5. Verify TLS + reach
curl -sS https://twelve.solvulator.com/healthz
```

## Rollback

```sh
ssh -t nabla 'sudo systemctl disable --now twelve.service && \
              sudo rm /etc/systemd/system/twelve.service && \
              sudo systemctl daemon-reload'
# Manually remove the twelve.solvulator.com block from /etc/caddy/Caddyfile
ssh -t nabla 'sudo systemctl reload caddy'
```

## Notes

- `TWELVE_ROOT=/home/uprootiny` makes twelve walk nabla's home dir,
  not the mac workspace. Cards 01–10 will mostly be FAIL on nabla
  (no scaffold there) — that is honest output, not a bug.
- DNS for `twelve.solvulator.com` must point to nabla's public IP,
  same as the other `*.solvulator.com` entries. Caddy auto-provisions
  the cert via Let's Encrypt on first request.
