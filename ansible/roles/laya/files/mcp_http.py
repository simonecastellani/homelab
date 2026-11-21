"""Serve the Laya MCP server over streamable HTTP.

The upstream entry point (`laya-mcp-server`) only speaks stdio, which a remote
MCP client cannot reach. The server object it builds is transport-agnostic, so
running it with `transport="streamable-http"` gives one long-lived HTTP endpoint
at /mcp that any MCP client can connect to.

Predictions are proxied to laya-serve through LAYA_BASE_URL, so this process
never loads a checkpoint: the container stays small and the model cache is
shared with the API service.
"""

import os

from laya.mcp.server import server

server.run(
    transport="streamable-http",
    host=os.environ.get("LAYA_MCP_HOST", "0.0.0.0"),
    port=int(os.environ.get("LAYA_MCP_PORT", "8080")),
)
