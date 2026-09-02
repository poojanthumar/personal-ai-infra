# personal-ai-infra

Hub-and-spoke personal AI setup (Mac + Oracle VM). Website hosting for **poojanthumar.in** is documented here; application code lives in [personal-website-handler](https://github.com/poojanthumar/personal-website-handler).

## poojanthumar.in (Oracle + Caddy, no Cloudflare Tunnel)

- [24 — Caddy / DNS / TLS (verified + remaining subdomain certs)](docs/24-poojanthumar-in-oracle-proxy.md)
- [25 — App as built (Host routing, www / wedding / admin)](docs/25-personal-website-handler.md)
- [26 — VM deploy runbook](docs/26-poojanthumar-in-vm-deploy.md)

Caddyfile and systemd unit: [deploy/website/](deploy/website/).
