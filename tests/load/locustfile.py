#!/usr/bin/env python3
"""Load test for EAG using Locust.

Run with: locust -f tests/load/locustfile.py --host=https://eag.yourcompany.com
"""

from locust import HttpUser, task, between
import json


class MCPUser(HttpUser):
    """Simulates MCP client making tool calls."""

    wait_time = between(1, 3)  # 1-3 seconds between requests

    def on_start(self):
        """Called when user starts."""
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.environment.parsed_options.token}",
        }

    @task(5)
    def list_tools(self):
        """List available tools (common operation)."""
        self.client.post(
            "/",
            headers=self.headers,
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list",
            },
            name="tools/list",
        )

    @task(3)
    def call_read_tool(self):
        """Call a read tool."""
        self.client.post(
            "/",
            headers=self.headers,
            json={
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "read_file",
                    "arguments": {"path": "/workspace/README.md"},
                },
            },
            name="tools/call/read",
        )

    @task(1)
    def call_search_tool(self):
        """Call a search tool (more expensive)."""
        self.client.post(
            "/",
            headers=self.headers,
            json={
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "search_files",
                    "arguments": {"query": "TODO", "path": "/workspace"},
                },
            },
            name="tools/call/search",
        )


# Add custom CLI argument for auth token
from locust import events


@events.init_command_line_parser.add_listener
def _(parser):
    parser.add_argument("--token", type=str, default="", help="JWT auth token")
