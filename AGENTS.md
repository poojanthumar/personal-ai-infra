# Personal AI infrastructure

This repository is the source of truth for the Oracle VM, Mac worker, networking,
backups, and deployment operations. Read `docs/ai-stack-build/00-START-HERE.md`
and `docs/ai-stack-build/01-PROGRESS.md` before changing the architecture. Read
`COLLABORATION.md` when work crosses repositories or tasks.

- Keep runnable operational files under `ops/`; do not leave the only copy on a VM.
- Never commit passwords, API keys, tokens, private keys, or populated `.env` files.
- The VM is `ubuntu@100.105.56.99` over Tailscale. Public ports 80/443 terminate at Caddy.
- PostgreSQL and website port 8080 stay on localhost. Queue port 8000 is Tailscale-only.
- Website source belongs in `/Users/poojanthumar/Documents/Code/personal-website-handler`.
- VM website checkout: `/opt/website-handler`; service: `website-handler`; proxy: Caddy.
- Before a VM change, inspect current state. After it, verify service health and public HTTPS.
- For website delivery: test and commit in the website repo, push `main`, pull the exact commit
  on the VM, build, restart, check `/actuator/health`, then check all three public hosts.
- Preserve the previous VM commit until verification succeeds so rollback is one checkout away.
- Remote website agents work in `/home/ubuntu/workspaces/personal-website-handler`, never in
  `/opt/website-handler`. Their branch, preview, release, status, and rollback rules live in
  the website repository's `AGENTS.md` and `deploy/` scripts.
- `test.wedding.poojanthumar.in` is an expiring branch preview on localhost:9080. The
  `website-preview` service stays disabled and is started only during active website work.
