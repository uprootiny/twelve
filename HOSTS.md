# Hosts

Snapshot of the fleet as it pertains to twelve. Verified 2026-05-07.

## hyle (this mac, dev)

- macOS, the workspace lives at `/Users/uprootiny/Erlich`
- Python 3.9.6, bb 1.12.218, node 22.22.1
- Local twelve runs at `127.0.0.1:9412`
- Source of truth for the repo, pushes to `github.com/uprootiny/twelve`

## hub2 (production · publicly reachable)

- **149.102.137.139** (Contabo VM, hostname `vmi2545689`)
- Ubuntu 24.04, Python 3.12.3, caddy 2.10.2
- Wildcard DNS: `*.raindesk.dev` and `*.hyperstitious.art` → 149.102.137.139
  (verified — `asdfqwer.raindesk.dev` resolves)
- Existing site blocks: ~57 in `/etc/caddy/Caddyfile` (raindesk.dev,
  raindeck.dev, hyperstitious.art subdomains)
- Externally reachable on :443, :80, and high ports we test
  (:47312 verified). Real internet host.
- Sudo: interactive, not NOPASSWD by default. After
  `deploy/hub2/install.sh` runs, NOPASSWD is granted for
  `systemctl reload/restart caddy` and `caddy validate/fmt`.
- **Twelve lives here.** User-level systemd unit
  (`~/.config/systemd/user/twelve.service`), linger enabled.

## nabla (internal · tailscale-only)

- **35.252.20.194** (GCP, hostname `instance-20260314-013434`)
- Local interfaces: `10.208.0.4` (private VPC) and
  `100.126.58.126` (tailscale). The 35.252 IP is GCP's NAT — but
  ingress to the VM is closed at the project/VPC level. GCP firewall
  rules at the project tier we tested didn't open it.
- Caddy 2.11.2 + nginx, hosting `solvulator.com`,
  `app.solvulator.com`, `cockpit.solvulator.com`, `report.solvulator.com`.
- All cockpit/etc. access happens via tailscale (the user's machines are
  on the same tailnet).
- Solvulator backend runs here on `:9800` (production).
- Sudo: interactive, no NOPASSWD anywhere. `sudo-rs` (modern variant).
- **Twelve does NOT live here for public access.** A historical deploy
  (in `deploy/nabla/`) is left as reference but never reachable from
  outside.

## hub2's neighbours (other public hosts)

| host        | role                        | accessible? |
| ----------- | --------------------------- | ----------- |
| `karlsruhe` | NixOS, caddy, minimal       | not tested  |
| `finml`     | nginx, `*.uprootiny.dev`    | publicly serves |
| `gcp1`      | bare debian, no proxy yet   | unconfirmed |

These are deployment options for future surfaces if hub2's load grows or if
a surface fits another domain better.

## SSH gotcha (applies to all hosts)

`~/.ssh/config` has a global `RemoteCommand tmux new -A -s main` and
`RequestTTY yes`. rsync and any non-interactive ssh need:

```sh
ssh -o RemoteCommand=none -o RequestTTY=no <host>
rsync -e "ssh -o RemoteCommand=none -o RequestTTY=no" <args>
```

Without those flags the remote shell tries to attach to a tmux session and
your command vanishes.

## Why hub2 is the right home for surfaces

For *publicly reachable* surfaces:

- DNS wildcard already in place → arbitrary subdomain names without action
- Caddy already running with TLS automation
- Public ingress actually open — no firewall mystery
- Different cloud from solvulator backend, so a hub2 outage doesn't
  take solvulator down with it
- Sufficient port range available (high ports uncontested)

Nabla stays the home of *private* infrastructure and the solvulator backend.
The natural separation: public reasoning surface on hub2, sensitive backend
work on nabla, mac for local development.
