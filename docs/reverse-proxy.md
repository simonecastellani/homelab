# Reverse Proxy and Public HTTPS Access

Caddy runs in the dedicated `reverseproxy` LXC (`192.168.178.205`). Cloudflare
terminates public TLS, then connects to Caddy over HTTPS using an Origin CA
certificate. Only the LAN and published Cloudflare IP ranges can reach the
configured Caddy virtual hosts.

| Public hostname | Backend |
|---|---|
| `https://ha.simonecastellani.com` | Home Assistant on `192.168.178.202:8123` |
| `https://laminar.simonecastellani.com` | Laminar frontend on `192.168.178.204:5667` |
| `https://ingest.simonecastellani.com/v1/traces` | Laminar OTLP/HTTP on port `8000` and OTLP/gRPC on port `8001` |

The ingest hostname accepts OTLP/HTTP only on `/v1/traces` and routes gRPC to
the dedicated ingestion port. Both HTTP and gRPC clients use public port `443`;
Caddy connects to the gRPC backend over h2c. Ingestion requires a Laminar
Project API Key and must not be placed behind Cloudflare Access.

## Cloudflare

1. Create proxied DNS records for `ha`, `laminar`, and `ingest`, pointing to the
   router's static public IP.
2. Set SSL/TLS mode to **Full (strict)** and enable **Always Use HTTPS**.
3. Create an Origin CA certificate covering `*.simonecastellani.com` (and the
   apex domain, if desired).
4. Enable **Network → gRPC** and keep HTTP/2 enabled.
5. Forward only external TCP port `443` to `192.168.178.205:443` on the router.
   Do not forward ports `8000`, `8001`, `8123`, or `5667`.

## Home Assistant

Home Assistant 2026.8 and later manages HTTP proxy trust in the UI. Open
**Settings → System → Network → HTTP server**, enable **Trust X-Forwarded-For**,
and add `192.168.178.205` to **Trusted proxies**. Save and confirm the new
settings within five minutes. Do not add a new `http:` block to
`configuration.yaml`: after the UI migration it is ignored.

## GitHub OAuth for Laminar

Create a GitHub OAuth App with:

- Homepage URL: `https://laminar.simonecastellani.com`
- Authorization callback URL:
  `https://laminar.simonecastellani.com/api/auth/callback/github`

GitHub OAuth identifies users but does not, by itself, restrict which GitHub
accounts can sign up. This role does not configure an account allowlist. Before
exposing the frontend, verify that the deployed Laminar version supports the
required allowlist; otherwise use an additional access-control layer.

## Required CI secrets

| Secret | Value |
|---|---|
| `CLOUDFLARE_ORIGIN_CERT` | Full Origin CA certificate in PEM format |
| `CLOUDFLARE_ORIGIN_KEY` | Origin CA private key in PEM format |
| `LAMINAR_AUTH_SECRET` | Random secret of at least 32 bytes |
| `LAMINAR_GITHUB_OAUTH_ID` | GitHub OAuth App client ID |
| `LAMINAR_GITHUB_OAUTH_SECRET` | GitHub OAuth App client secret |

For a manual Ansible run, export the same names as environment variables before
running the playbook. Never commit these values or write them to shell history.

## Laminar SDK configuration

Use `https://ingest.simonecastellani.com` as the base URL and set both the HTTP
and gRPC ports to `443`. Authenticate with the Project API Key from Laminar.

## Verification

- Home Assistant loads and its real-time UI updates work over HTTPS.
- GitHub OAuth returns successfully to the Laminar dashboard.
- OTLP/HTTP and OTLP/gRPC exporters both deliver traces to Laminar.
- Requests to the ingest endpoint without a valid Project API Key are rejected.
- Direct public access to the backend ports is not possible.
