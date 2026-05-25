# Router Public Deployment

This guide exposes Metabase publicly through your home/office router.

Recommended public architecture:

```text
Internet
  -> Router public IP
  -> port forward TCP 80/443
  -> Ubuntu server 192.168.50.206
  -> Caddy reverse proxy
  -> Metabase container
  -> PostgreSQL container stays private
```

Do not expose PostgreSQL `5432` to the public internet.

## Requirements

You need:

```text
1. A domain name, such as metabase.example.com
2. DNS A record pointing to your router public IP
3. Router port forwarding for TCP 80 and 443
4. Ubuntu server LAN IP, currently 192.168.50.206
```

If your ISP uses CGNAT, router forwarding will not work from the public internet. In that case use Cloudflare Tunnel or Tailscale instead.

## DNS

Create:

```text
Type: A
Name: metabase
Value: your router public IPv4 address
Proxy/CDN: DNS only, at least until HTTPS works
```

## Router Port Forwarding

On your router, forward:

```text
TCP 80  -> 192.168.50.206:80
TCP 443 -> 192.168.50.206:443
```

Do not forward:

```text
3000
5432
5050
```

## Ubuntu Firewall

If UFW is enabled:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status
```

## Start Services

On the Ubuntu server:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/*.sh

sudo ./scripts/start_postgres_server.sh
sudo ./scripts/start_metabase_server.sh

sudo PUBLIC_HOSTNAME='metabase.example.com' ACME_EMAIL='you@example.com' ./scripts/start_public_caddy.sh
```

Caddy will automatically request and renew HTTPS certificates from Let's Encrypt.

Open:

```text
https://metabase.example.com
```

## If Server Port 80 Is Already Used

If Caddy fails with:

```text
failed to bind host port 0.0.0.0:80/tcp: address already in use
```

Either stop the service using port 80, or run Caddy on alternate internal ports:

```bash
sudo PUBLIC_HOSTNAME='metabase.example.com' \
ACME_EMAIL='you@example.com' \
PUBLIC_HTTP_PORT=8080 \
PUBLIC_HTTPS_PORT=8443 \
./scripts/start_public_caddy.sh
```

Then change router forwarding to:

```text
TCP 80  -> 192.168.50.206:8080
TCP 443 -> 192.168.50.206:8443
```

External users still open:

```text
https://metabase.example.com
```

## Metabase Security

Before exposing publicly:

```text
Change any password that was pasted into chat or screenshots.
Use strong passwords for all Metabase accounts.
Only you should have Metabase admin permissions.
Give teammates normal user permissions.
Keep PostgreSQL private and use read-only DB users for modeling.
```

## Teammate Access

For browser usage:

```text
https://metabase.example.com
```

For Python/R model training:

```text
Prefer Tailscale or SSH tunnel for direct PostgreSQL access.
Do not expose PostgreSQL 5432 publicly.
```

If a teammate cannot use Tailscale, they can export CSV from Metabase:

```text
research.monthly_macro_features
```

## Public IP Without Domain

If you do not own a domain, you can expose Metabase over plain HTTP by forwarding an external port to Metabase.

Server:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/*.sh

sudo ./scripts/start_postgres_server.sh
sudo ./scripts/start_metabase_public_ip.sh
```

Router forwarding:

```text
TCP 8080 -> 192.168.50.206:3000
```

External users open:

```text
http://your-public-ip:8080
```

This is not encrypted. Use it only as a temporary setup, or put the service behind Tailscale, Cloudflare Tunnel, or a real domain with HTTPS later.

## Quick Checks

On the server:

```bash
sudo docker ps
curl -I http://127.0.0.1
```

From outside your network:

```bash
curl -I https://metabase.example.com
```
