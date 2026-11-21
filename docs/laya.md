# Laya decision engine

[Laya](https://github.com/NandhaKishorM/laya) is a local decision engine for
cheap typed decisions (classification, routing, triage, scoring, yes/no). The
`laya` Ansible role deploys it on the opencode VM (`192.168.178.203`) as a
Docker Compose project under `/opt/laya`, and the reverse proxy publishes its
MCP server at `https://laya.simonecastellani.com/mcp`.

## Architecture

| Service | Published on | Purpose |
|---|---|---|
| `laya-serve` | `127.0.0.1:8001` | Laya HTTP API (`/health`, `/v1/systemone`, …) |
| `laya-mcp` | `0.0.0.0:8000` | MCP server over Streamable HTTP at `/mcp` |

`laya-mcp` runs in *remote* mode: it points at `http://laya-serve:8000` through
`LAYA_BASE_URL`, so it holds no checkpoint itself. Both containers share the
`laya_model-cache` volume, and `laya-serve` preloads the checkpoints at startup
(`LAYA_PRELOAD=1`).

The MCP process only speaks stdio upstream; the role mounts `mcp_http.py` into
the container and calls the same server object with
`transport="streamable-http"`, which is what makes a remote client possible
without an extra bridge.

## Files on the VM

| Path | Content |
|---|---|
| `/opt/laya/compose.yml` | Compose project, rendered by the role |
| `/opt/laya/src` | Upstream checkout at the pinned release |
| `/opt/laya/mcp/Dockerfile` | Thin layer adding the `laya[mcp]` extra |
| `/opt/laya/mcp/mcp_http.py` | Streamable HTTP entrypoint |
| `/opt/laya/.built-ref` | Release the images were built from |

## Configuration

The role defaults live in `ansible/roles/laya/defaults/main.yml`. The release
is pinned with `laya_git_ref`; changing it rebuilds both images on the next
run (the `.built-ref` marker skips the ~2 GB build otherwise).

The public endpoint requires a bearer token, read from the `LAYA_MCP_TOKEN`
secret by the `reverse_proxy` role.

## Client configuration

Remote MCP clients use the Streamable HTTP transport:

```json
{
  "mcp": {
    "laya": {
      "type": "remote",
      "url": "https://laya.simonecastellani.com/mcp",
      "headers": { "Authorization": "Bearer <LAYA_MCP_TOKEN>" },
      "enabled": true
    }
  }
}
```

Inside the VM, the role writes `/home/opencode/.config/opencode/opencode.json`
pointing at `http://127.0.0.1:8000/mcp`, which needs no token.

## Verification

```bash
# Liveness of the API (from the VM)
curl -s http://127.0.0.1:8001/health

# MCP initialize through the public endpoint
curl -sS -X POST https://laya.simonecastellani.com/mcp \
  -H "Authorization: Bearer $LAYA_MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}'
```

The response is a `serverInfo` payload with `"name": "laya"`. Without the
authorization header Caddy answers `401`.

## Notes

- The images are built on the VM and never pulled: the first run downloads the
  CPU PyTorch wheels and the checkpoints (roughly 2 GB in the cache volume).
- A manual install may still exist at `/root/laya` on the VM. It is unused by
  this project and can be removed once the role has run.
- `docker compose up` targets only `laya-serve` and `laya-mcp`, so the upstream
  one-shot quickstart service never starts.
