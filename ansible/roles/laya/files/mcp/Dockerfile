# Thin layer on top of the image built from the upstream compose file: it adds
# only the `mcp` extra (mcp>=2.2.0), so the Laya MCP server can run inside the
# same environment. The server itself is started by mcp_http.py, mounted from
# the host, which serves the MCP protocol over streamable HTTP instead of stdio.
FROM laya-laya-serve:latest
USER root
RUN /opt/venv/bin/pip install --no-cache-dir "laya[mcp]" \
    && /opt/venv/bin/pip check
USER 10001
