# 24 — poojanthumar.in on the Oracle VM (Caddy)

**Status (2026-09-02):** DNS and Caddy HTTP→HTTPS are live. TLS works for the **apex only**. Subdomains fail TLS until the Caddyfile in [deploy/website/Caddyfile](../deploy/website/Caddyfile) is installed (file 26). **No Cloudflare Tunnel.**

**App code:** [poojanthumar/personal-website-handler](https://github.com/poojanthumar/personal-website-handler) `main` (`dc49dc8`, PR #3).

---

## Target layout

```
Browser
  → Caddy :80 / :443  (public; Let's Encrypt)
      Host poojanthumar.in     → 301 https://www.poojanthumar.in{uri}
      Host www / wedding / admin → reverse_proxy 127.0.0.1:8080
  → Spring Boot 127.0.0.1:8080  (not in Oracle Security List)
  → Postgres db `website` on localhost (not the aihub job-queue DB)
```

Keep **80 and 443** open on the VM. Do not open **8080** or **5432**. Do not use Cloudflare Tunnel for this domain.

---

## Verified from outside the VM

Oracle public IP: `129.225.94.223` ([dev/env.defaults](../dev/env.defaults)).

| Check | Result |
|---|---|
| `poojanthumar.in` A | `129.225.94.223` |
| `www.poojanthumar.in` | CNAME to apex → same IP |
| `wedding.poojanthumar.in` A | `129.225.94.223` |
| `admin.poojanthumar.in` A | `129.225.94.223` |
| HTTP :80 all four names | `308` to HTTPS, `Server: Caddy` |
| `https://poojanthumar.in` | `200`, Let's Encrypt, SAN **only** `poojanthumar.in`, static Hello HTML (file_server, Last-Modified 2026-08-26) |
| `https://www` / `wedding` / `admin` | TCP 443 connects, then TLS alert 80 (no cert for those names) |
| `:8080` from internet | closed |
| Cloudflare headers | none |

This agent could not SSH (no Oracle private key in the Cloud Agent). Tailscale ping to `100.105.56.99` (`personal`) works via DERP; SSH to that IP from the agent timed out.

---

## What you still configure on the box

1. **Oracle VCN:** Security List and NSG already allow 80/443 (HTTP works). Leave them.
2. **OS firewall:** 80/443 allowed; 8080/5432 localhost-only.
3. **Caddyfile:** replace the current apex `file_server` with [deploy/website/Caddyfile](../deploy/website/Caddyfile). Caddy will request Let's Encrypt certs for `www`, `wedding`, and `admin` (HTTP-01 on port 80).
4. **Apex:** 301 to `www` so Spring Boot never needs `poojanthumar.in` in `app.hosts.www`.
5. Backup the live Caddyfile before replacing it (`sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak-$(date +%F)`). Paths may be `/etc/caddy/Caddyfile` or a custom unit `Caddyfile` — check `systemctl cat caddy`.

After reload, `curl -I https://www.poojanthumar.in` must be TLS OK (even if Spring is still down → 502). Today it is TLS fail.

---

## Related

- App shape: [25](25-personal-website-handler.md)
- Deploy runbook: [26](26-poojanthumar-in-vm-deploy.md)
