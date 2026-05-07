# Deploy

How twelve gets to production, and how to add the next surface.

## Production hosts: see HOSTS.md

Short version: **hub2 is the public host**, nabla is tailscale-only. Twelve
lives at `https://twelve.raindesk.dev/` and `http://149.102.137.139:47312/`.

## First deploy on hub2

One-time, requires interactive sudo on hub2. From this mac:

```sh
rsync -av -e "ssh -o RemoteCommand=none -o RequestTTY=no" \
      --exclude='.git' --exclude='.twelve.*' --exclude='__pycache__' \
      ./ hub2:/home/uprootiny/twelve/

bash deploy/hub2/install.sh
```

`install.sh` is idempotent and does five things in one sudo session:

1. **Carve `/etc/caddy/conf.d/`** owned by `uprootiny` and add
   `import /etc/caddy/conf.d/*.caddyfile` to `/etc/caddy/Caddyfile`.
   After this, dropping a `.caddyfile` in `conf.d/` is enough — no sudo
   needed for the snippet itself, only for the reload.
2. **Install `/etc/sudoers.d/uprootiny-caddy`** allowing
   `systemctl reload caddy`, `systemctl restart caddy`, `caddy validate`,
   and `caddy fmt` without password. Validates with `visudo -cf` before
   activation.
3. **Drop `twelve.caddyfile`** into `/etc/caddy/conf.d/`. Reverse-proxies
   `twelve.raindesk.dev` to `127.0.0.1:47312`, with gzip/zstd encoding.
4. **Validate + reload caddy.** Caddy auto-issues a Let's Encrypt cert on
   first request to the new subdomain.
5. **Install user-level systemd unit** at
   `~/.config/systemd/user/twelve.service`, hand off from any nohup
   instance, enable linger so the unit persists past logout.

## Adding a new surface (the family pattern)

Once `install.sh` has run once, every subsequent surface skips the sudo
prompt entirely.

1. Build the surface as a small repo of its own (its own `verify`,
   its own `bring-live`).
2. Pick a fresh subdomain — anything under `*.raindesk.dev` resolves
   already (verified wildcard).
3. Pick a fresh high port (40000–49999 range, uncontested on hub2).
4. rsync the code:
   ```sh
   rsync -av -e "ssh -o RemoteCommand=none -o RequestTTY=no" \
         --exclude='.git' ./ hub2:/home/uprootiny/<name>/
   ```
5. Drop the snippet (no sudo — `conf.d/` is owned by you):
   ```sh
   ssh hub2 "cat > /etc/caddy/conf.d/<name>.caddyfile <<EOF
   <name>.raindesk.dev {
       reverse_proxy 127.0.0.1:<port>
       encode gzip zstd
   }
   EOF"
   ```
6. Reload caddy (passwordless thanks to sudoers rule):
   ```sh
   ssh hub2 sudo systemctl reload caddy
   ```
7. Drop a user systemd unit (no sudo):
   ```sh
   ssh hub2 "cat > ~/.config/systemd/user/<name>.service <<EOF
   ... unit text ...
   EOF
   systemctl --user daemon-reload
   systemctl --user enable --now <name>
   "
   ```

That's the whole loop. No `/etc/systemd/system/` writes, no
`/etc/caddy/Caddyfile` edits, no firewall changes (high port range is
already open at the cloud level for hub2).

## Why not nabla

`deploy/nabla/finish-everything.sh` and the matching unit/snippet are kept
in `deploy/nabla/` for reference. They install correctly on nabla and
twelve runs internally — but the box is firewalled at the cloud-platform
level. Existing access to `*.solvulator.com` happens over tailscale, which
is fine for cockpit/admin but doesn't make twelve reachable to a normal
browser. After several attempts to open ingress at the GCP firewall layer
without success, the right call was to relocate. Don't fight clouds.

If we ever want twelve reachable as `twelve.solvulator.com`, the cleanest
fix is a CNAME `twelve.solvulator.com → twelve.raindesk.dev` at the DNS
registrar — keeps the brand naming, routes traffic to the host that
actually serves.

## Rollback

User systemd unit (no sudo):
```sh
ssh hub2 "systemctl --user disable --now twelve.service && \
          rm ~/.config/systemd/user/twelve.service"
```

Caddy snippet (no sudo to remove, sudo for reload):
```sh
ssh hub2 "rm /etc/caddy/conf.d/twelve.caddyfile && \
          sudo systemctl reload caddy"
```

Repo on hub2:
```sh
ssh hub2 rm -rf /home/uprootiny/twelve
```

DNS: nothing to undo (subdomain is wildcard-resolved; once the snippet is
gone caddy returns "no site for this host").
