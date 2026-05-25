# Public Deployment

Use Cloudflare Tunnel to expose Metabase to the public internet without opening inbound ports on the Ubuntu server.

Official Cloudflare notes:

```text
Cloudflare Tunnel uses outbound-only cloudflared connections, so no inbound firewall ports are required.
For remotely-managed tunnels, the server only needs the tunnel token.
```

Sources:

```text
https://developers.cloudflare.com/tunnel/
https://developers.cloudflare.com/tunnel/setup/
https://developers.cloudflare.com/tunnel/advanced/tunnel-tokens/
```

## Recommended Exposure

Expose:

```text
Metabase: https://metabase.your-domain.com
```

Do not expose:

```text
PostgreSQL 5432
```

Keep PostgreSQL private through Tailscale, SSH tunnel, or a future authenticated API/JupyterHub layer.

## Cloudflare Dashboard Setup

1. Add your domain to Cloudflare.
2. Go to `Zero Trust` or `Cloudflare One`.
3. Go to `Networks -> Tunnels`.
4. Create a tunnel, for example:

```text
faib-research-metabase
```

5. Add a public hostname:

```text
Hostname: metabase.your-domain.com
Service type: HTTP
Service URL: http://fred_macro_metabase:3000
```

6. Copy the tunnel token.

The token is secret. Do not commit it to GitHub.

## Server Setup

On Ubuntu:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/*.sh

sudo ./scripts/start_postgres_server.sh
sudo ./scripts/start_metabase_server.sh

sudo TUNNEL_TOKEN='eyJ...' ./scripts/start_cloudflare_tunnel.sh
```

Then open:

```text
https://metabase.your-domain.com
```

## Metabase User Setup

In Metabase:

```text
Admin settings -> People -> Invite someone
```

Create one Metabase account per teammate.

Recommended permissions:

```text
View/query only for FRED Macro Research DB
No admin access
No database management access
```

## Model Training Access

For models, teammates have two options.

### Option A: Direct Database Access

Use personal PostgreSQL read-only accounts over Tailscale:

```text
postgresql+psycopg2://member01:password@100.72.157.21:5432/fred_macro
```

This is best for Python/R/Notebook model training.

### Option B: Metabase Export

Use Metabase to download CSV from:

```text
research.monthly_macro_features
```

This is easier for teammates who do not need direct database access.

## Security Checklist

```text
Change any password that was pasted into chat or screenshots.
Do not expose PostgreSQL publicly.
Use strong Metabase passwords.
Consider Cloudflare Access login in front of Metabase.
Keep each teammate on a personal DB account for usage monitoring.
```
