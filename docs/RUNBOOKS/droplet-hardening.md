# Droplet hardening runbook

Production host: `twlv20-prod` (`162.243.252.92`).

## Current access

- Root SSH is disabled.
- Password SSH auth is disabled.
- Key-only SSH users:
  - `keeper`
  - `jon`
  - `twlv20-deploy`

Use:

```bash
ssh keeper@162.243.252.92
```

or:

```bash
ssh jon@162.243.252.92
```

Both users have sudo. Do not depend on `root@162.243.252.92` SSH.

## Firewall

UFW is active:

- default incoming: deny
- default outgoing: allow
- `22/tcp`: limit
- `80/tcp`: allow
- `443/tcp`: allow

Check:

```bash
sudo ufw status verbose
```

## SSH hardening

Drop-in file:

```text
/etc/ssh/sshd_config.d/99-twlv20-hardening.conf
```

Important settings:

- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `AllowUsers keeper jon twlv20-deploy`

Cloud-init override was also set to:

```text
/etc/ssh/sshd_config.d/50-cloud-init.conf
PasswordAuthentication no
```

Verify effective config:

```bash
sudo sshd -T | egrep '^(permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|allowusers) '
```

## Caddy

Caddy is installed from the official Caddy apt repo and active.

Current baseline Caddyfile:

```text
/etc/caddy/Caddyfile
```

Current behavior: port `80` returns a simple health message. Public host routing and automatic TLS are pending DNS/domain confirmation.

Check:

```bash
systemctl is-active caddy
curl -fsS http://127.0.0.1/
```

## fail2ban

fail2ban is active with jails:

- `sshd`
- `caddy-status`

Check:

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status caddy-status
```

## Deferred items

- Configure real DNS/hostnames for `paperclip.<domain>`, `claw.<domain>`, and `infisical.<domain>`.
- Update `/etc/caddy/Caddyfile` with host-based reverse proxies once DNS is confirmed.
- Confirm public TLS handshake after DNS points at the droplet.
