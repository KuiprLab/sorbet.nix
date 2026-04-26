# sorbet.nix

NixOS homelab — two hosts managed with [deploy-rs](https://github.com/serokell/deploy-rs) and [flake-parts](https://github.com/hercules-ci/flake-parts).

## Hosts

| Host     | Role                | Location            |
| -------- | ------------------- | ------------------- |
| `sorbet` | Main homelab server | LAN `192.168.0.85`  |
| `eclair` | Public-facing VPS   | Tailnet + public IP |

## Architecture

```
Internet
   │
   ▼
eclair (VPS)
  haproxy :443 — TCP SNI passthrough
  CrowdSec — nftables IP banning
   │ tailnet
   ▼
sorbet (LAN)
  caddy — TLS termination (ACME via Bunny DNS)
  services — Navidrome, Home Assistant, etc.
```

`*.ext.kuipr.de` DNS records point to eclair's public IP. haproxy inspects the TLS SNI header, matches against all `*.ext.kuipr.de` virtual hosts declared in the flake, and TCP-proxies the connection to sorbet over Tailscale. Caddy on sorbet terminates TLS end-to-end — eclair never sees plaintext.

`*.int.kuipr.de` resolves to `192.168.0.85` via dnsmasq wildcard — LAN only, not routed through eclair.

## Module structure

All `.nix` files under `modules/` are auto-imported by `import-tree`. Files prefixed `_` are skipped (imported manually by their parent module).

Service modules contribute to the flake via:

- `flake.nixosModules.*` — applied to **sorbet**
- `flake.eclairNixosModules.*` — applied to **eclair**
- `flake.caddyVirtualHosts` — Caddy site blocks, also read by haproxy to auto-generate SNI ACLs

Adding a new public service: declare `flake.caddyVirtualHosts."myservice.ext.kuipr.de"` in the service module — haproxy picks it up automatically on next deploy.

## Secrets

Secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) using age keys. Files live under `secrets/<service>/<host>`.

| Secret file                     | Used by                                        |
| ------------------------------- | ---------------------------------------------- |
| `secrets/caddy/sorbet`          | Caddy — `BUNNY_API_KEY` for ACME DNS challenge |
| `secrets/tailscale/sorbet`      | sorbet tailscale auth key                      |
| `secrets/tailscale/eclair`      | eclair tailscale auth key                      |
| `secrets/crowdsec/eclair`       | CrowdSec firewall bouncer API key              |
| `secrets/homepage/sorbet`       | Homepage dashboard env vars                    |
| `secrets/gatus/sorbet`          | Gatus — Discord webhook                        |
| `secrets/github-runner/sorbet`  | GitHub Actions runner token                    |
| `secrets/deploy-webhook/shared` | Discord deploy notifications                   |
| `secrets/rclone/sorbet`         | rclone Google Drive config                     |
| `secrets/beets/sorbet`          | beets config                                   |

Both hosts share a single age key listed in `.sops.yaml`.

### Age key

Both hosts use the same age private key stored at `/var/lib/sops/age-key.txt`. This file must exist before NixOS activation — sops-nix will fail to decrypt secrets without it.

The key is stored in 1Password. Upload it to either host with:

```bash
op read "op://Personal/sorbet.nix/Private Key" \
  | ssh root@sorbet "mkdir -p /var/lib/sops && cat > /var/lib/sops/age-key.txt && chmod 400 /var/lib/sops/age-key.txt"

op read "op://Personal/sorbet.nix/Private Key" \
  | ssh root@eclair "mkdir -p /var/lib/sops && cat > /var/lib/sops/age-key.txt && chmod 400 /var/lib/sops/age-key.txt"
```

## Deployment

### Deploy sorbet

```bash
just deploy sorbet
```

### Deploy eclair

```bash
just deploy eclair
```

The `deploy` recipe calls `scripts/deploy.sh`, which uses deploy-rs for remote hosts. `remoteBuild = false` for eclair — the closure is built locally and pushed to the VPS.

### Fresh install (nixos-anywhere)

```bash
just install root@<target-ip>
```

Installs NixOS from scratch via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere). The `config` variable at the top of the justfile controls which flake target is installed.

### Build without deploying

```bash
just build
```

Runs `nix fmt` + `nix flake check` + builds the sorbet toplevel locally (requires a Linux builder on macOS).

## CrowdSec (eclair)

CrowdSec runs on eclair as agent + nftables firewall bouncer. The agent watches haproxy and sshd journals for attack signals and feeds decisions to the bouncer, which DROPs banned IPs via nftables before they reach haproxy.

### Check active bans

```bash
ssh root@eclair cscli decisions list
```

### Check alerts

```bash
ssh root@eclair cscli alerts list
```

### Update hub (collections/parsers/scenarios)

```bash
ssh root@eclair cscli hub update && cscli hub upgrade
```

### Unban an IP

```bash
ssh root@eclair cscli decisions delete --ip <ip>
```

## Adding a new external service

1. In the service's `.nix` file, add a `flake.caddyVirtualHosts."myservice.ext.kuipr.de"` entry.
2. Point `myservice.ext.kuipr.de` DNS A record to eclair's public IP.
3. Deploy sorbet (caddy picks up new vhost) then eclair (haproxy regenerates SNI ACLs).

No other changes needed — SNI routing is derived automatically from `caddyVirtualHosts`.

## Updating flake inputs

```bash
just update-inputs
```

## Running beets on sorbet

```bash
just beet import ~/Downloads/album
just beet <any beet command>
```
