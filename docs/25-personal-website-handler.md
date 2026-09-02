# 25 — personal-website-handler (as built)

One Spring Boot 4 / Java 21 process. Routing is the HTTP **Host** header, not extra ports.

Repo: https://github.com/poojanthumar/personal-website-handler  
Merged: PR #3 (`Serve www, wedding, and admin sites from the HTTP Host header`).

---

## Hosts

| Host | Aliases (local) | What |
|---|---|---|
| `www.poojanthumar.in` | `www.localhost`, `localhost`, `127.0.0.1` | Portfolio + contact form |
| `wedding.poojanthumar.in` | `wedding.localhost` | `/` homepage, `/roka` |
| `admin.poojanthumar.in` | `admin.localhost` | Login, explorer, CRUD |

Unknown hosts → 404 template. Apex `poojanthumar.in` is **not** a Boot host; Caddy 301s it to `www` (file 24).

Later wedding phases (engagement, date reveal, digital invites) are out of this version.

---

## Stack

- Thymeleaf + static CSS (`www.css`, `wedding.css`, `admin.css`)
- Spring Security: www + wedding public; admin form login + HTTP Basic; `GET /api/contact` admin-only
- JPA + Flyway: `contact_messages`, `wedding_content` (seeded home + roka)
- Default profile: H2. Production: `postgres` profile (`application-postgres.properties`)
- Admin user: `ADMIN_USER` / `ADMIN_PASSWORD` (defaults `admin` / `change-me` — override on the VM)

---

## Local check (already run on 2026-09-02)

```bash
./mvnw test          # 10 tests, BUILD SUCCESS
./mvnw spring-boot:run
curl -H 'Host: www.poojanthumar.in' http://127.0.0.1:8080/
curl -H 'Host: wedding.poojanthumar.in' http://127.0.0.1:8080/roka
curl -D- -H 'Host: admin.poojanthumar.in' http://127.0.0.1:8080/   # 302 /login
```

Contact JSON `POST /api/contact` is public; list is 401 without admin Basic.

---

## Production bind

On the VM, Boot must listen on **127.0.0.1:8080** only (`--server.address=127.0.0.1`) behind Caddy. Profile `postgres`. Database name `website` — not `aihub`.
