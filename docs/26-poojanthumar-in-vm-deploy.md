# 26 — Deploy personal-website-handler to the Oracle VM

Run this **on the VM** (or SSH from your Mac). This Cloud Agent cannot SSH: the Oracle key is not in the environment.

Mac SSH (from [docs/code/oracle/code](code/oracle/code)):

```bash
ssh -i /Users/poojanthumar/Library/Mobile\ Documents/com~apple~CloudDocs/Code/secrets/ssh-keys-oracle-vm.key ubuntu@129.225.94.223
```

No Cloudflare Tunnel. Public ports stay 80/443 on Caddy only.

---

## 1. Packages (aarch64)

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jre-headless postgresql git
java -version   # 21
```

Caddy is already installed and serving the apex.

---

## 2. Postgres database `website`

Do **not** put these tables in `aihub`.

```bash
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'website') THEN
    CREATE ROLE website LOGIN PASSWORD 'REPLACE_WITH_LONG_PASSWORD';
  END IF;
END$$;
SQL
sudo -u postgres createdb -O website website
```

---

## 3. App checkout and jar

```bash
sudo mkdir -p /opt/website-handler
sudo chown ubuntu:ubuntu /opt/website-handler
cd /opt/website-handler
git clone https://github.com/poojanthumar/personal-website-handler.git .
./mvnw -B -DskipTests package
ls target/*.jar
```

Copy env:

```bash
# from this infra repo, or paste deploy/website/env.example
install -m 600 /dev/null /opt/website-handler/.env
```

Fill `/opt/website-handler/.env`:

```
SPRING_PROFILES_ACTIVE=postgres
SERVER_ADDRESS=127.0.0.1
SERVER_PORT=8080
DATABASE_URL=jdbc:postgresql://127.0.0.1:5432/website
DATABASE_USER=website
DATABASE_PASSWORD=REPLACE_WITH_LONG_PASSWORD
ADMIN_USER=admin
ADMIN_PASSWORD=REPLACE_WITH_ADMIN_PASSWORD
```

---

## 4. systemd

Copy [deploy/website/website-handler.service](../deploy/website/website-handler.service) to `/etc/systemd/system/website-handler.service`.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now website-handler
curl -sS http://127.0.0.1:8080/actuator/health
```

Expect `{"status":"UP"}`.

---

## 5. Caddy (this is what unblocks www / wedding / admin TLS)

Backup, then install [deploy/website/Caddyfile](../deploy/website/Caddyfile):

```bash
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak-$(date +%F)
sudo cp /path/to/personal-ai-infra/deploy/website/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

If the unit uses a different config path, `systemctl cat caddy` and copy there instead.

Wait a minute for ACME, then from your laptop:

```bash
curl -sSI https://www.poojanthumar.in | head
curl -sSI https://wedding.poojanthumar.in/roka | head
curl -sSI https://admin.poojanthumar.in | head   # 302 to /login
curl -sSI https://poojanthumar.in | head         # 301/308 to www
```

TLS alert 80 on subdomains means Caddy still lacks those site blocks or ACME failed (`journalctl -u caddy -n 80`).

---

## 6. Redeploy after git changes

```bash
cd /opt/website-handler
git pull
./mvnw -B -DskipTests package
sudo systemctl restart website-handler
```

---

## Checklist

- [ ] Java 21 on the VM
- [ ] DB `website` / role `website`
- [ ] `.env` with real `ADMIN_PASSWORD` and DB password (`chmod 600`)
- [ ] `website-handler` healthy on loopback
- [ ] Caddyfile replaced; apex Hello static page gone
- [ ] HTTPS works for www, wedding, admin
- [ ] 8080 and 5432 not on the public Security List
