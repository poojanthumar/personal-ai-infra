# Working across infrastructure, website development, and deployment

Agents do not inherit reliable memory from unrelated chats. Shared context should live in
committed files, while each task prompt supplies the current outcome. `AGENTS.md` in each
repository tells Codex what that repository owns and where the boundary is.

The Oracle VM follows the same rule. Git records what changed and why; the checked-in agent
rules record how to work; `/home/ubuntu/website-deployments/history.tsv` records what actually
ran. A new agent reconstructs the current state by reading `AGENTS.md`, running
`deploy/status-on-vm.sh`, and reading recent git history. It does not need the earlier chat.

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

## Phone-driven remote website task

Connect Codex Desktop to the Oracle host and open
`/home/ubuntu/workspaces/personal-website-handler` as a project. A request such as
`I do not like the wedding homepage button; make it clearer` causes the repository agent to:

1. create a `codex/*` branch from `origin/main`;
2. implement and test the committed change;
3. start `https://test-<site>.poojanthumar.in` from that commit;
4. merge and push `main`, deploy the exact commit, verify it, and stop the preview.

Say `preview only` when you want to approve the preview before production. Say `roll back the
last website deployment` to run the recorded rollback target. The preview service uses a
separate database copy, is disabled at boot, and automatically stops after 24 hours.
The single DNS prerequisite is a wildcard `A` record for `*.poojanthumar.in`; adding a future
site or preview does not require another DNS record.

## Handoff contract

Every task should finish with the repository, commit hash, tests run, runtime changes, and
remaining risks. A new agent can reconstruct state from git, `AGENTS.md`, and the deployment
ledger. Paste a previous commit hash only when a task must refer to that particular change.

Use ChatGPT for product direction, copy, page structure, and design critique. Use Codex in
the website repository for implementation and tests, and Codex in this repository for VM
operations. Put lasting decisions into repository files instead of relying on chat history.
