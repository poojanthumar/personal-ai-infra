# Working across infrastructure, website development, and deployment

Agents do not inherit reliable memory from unrelated chats. Shared context should live in
committed files, while each task prompt supplies the current outcome. `AGENTS.md` in each
repository tells Codex what that repository owns and where the boundary is.

## 1. Infrastructure task

Open `/Users/poojanthumar/Documents/Code/personal-ai-infra` and ask Codex to inspect or
change VM, networking, queue, backup, or Mac-agent operations. It should update a file in
`ops/` before applying the same change to a machine, then verify the runtime.

Example prompt: `Fix the Oracle VM queue maintenance job. Read AGENTS.md, update the
checked-in ops source first, deploy it, and verify the next scheduled run.`

## 2. Website development task

Open `/Users/poojanthumar/Documents/Code/personal-website-handler` and ask Codex to build
the portfolio, wedding, admin, or backend feature. It should run `./mvnw test`, show the
result locally when visual review matters, and commit only after the change is reviewable.

Example prompt: `Build the wedding RSVP page. Read AGENTS.md, preserve host isolation,
add the Flyway migration and tests, and prepare a reviewable commit. Do not deploy yet.`

## 3. Deployment task

Start from the website repository after the desired commit is on `origin/main`. Run
`./deploy/deploy-vm.sh [commit]`. The script tests locally, deploys that exact commit,
rolls back after a failed health check, and verifies the public HTTPS hosts.

Example prompt: `Deploy the current origin/main using deploy/deploy-vm.sh. Report the old
and new commit, service health, and public checks.`

## Handoff contract

Every task should finish with the repository, commit hash, tests run, runtime changes, and
remaining risks. A new agent can reconstruct state from git plus `AGENTS.md`; paste the
previous commit hash into the next prompt when one task directly follows another.

Use ChatGPT for product direction, copy, page structure, and design critique. Use Codex in
the website repository for implementation and tests, and Codex in this repository for VM
operations. Put lasting decisions into repository files instead of relying on chat history.
