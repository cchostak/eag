#!/usr/bin/env python3
"""MCP command filter - blocks dangerous tool invocations.

This script acts as a transparent proxy between agentgateway and
an MCP server, inspecting tool calls and blocking dangerous operations.

Usage:
  python mcp_command_filter.py <mcp-server-command> [args...]

Example in config.yaml:
  stdio:
    cmd: python
    args:
      - /app/scripts/mcp_command_filter.py
      - npx
      - "-y"
      - "@modelcontextprotocol/server-filesystem"
      - "/workspace"
"""

import sys
import json
import re
import subprocess
from typing import Any, Optional

# Dangerous command patterns to block
BLOCKED_COMMAND_PATTERNS = [
    r'rm\s+-r?f',           # rm -rf, rm -f
    r'mkfs',                # Format filesystem
    r'dd\s+if=',            # Disk operations
    r'nc\s+-',              # Netcat
    r'ncat',                # Ncat
    r'>\s*/dev/sd',         # Write to disk devices
    r'curl.*\|.*sh',        # Pipe to shell
    r'wget.*\|.*bash',      # Pipe to bash
    r'chmod\s+777',         # Overly permissive
    r'chown\s+root',        # Change to root ownership
]

# Sensitive file paths to block
BLOCKED_PATHS = [
    r'^/etc/passwd',
    r'^/etc/shadow',
    r'^/root/',
    r'^/sys/',
    r'^/proc/',
    r'/\.ssh/',
    r'/\.aws/',
]

# Blocked tool names (exact match)
BLOCKED_TOOLS = {
    "execute_command",
    "run_command",
    "shell",
    "eval",
}


class SecurityError(Exception):
    """Raised when a security policy is violated."""
    pass


def check_command(cmd: str) -> None:
    """Check if command contains blocked patterns. Raises SecurityError if blocked."""
    for pattern in BLOCKED_COMMAND_PATTERNS:
        if re.search(pattern, cmd, re.IGNORECASE):
            raise SecurityError(f"Blocked command pattern: {pattern}")


def check_path(path: str) -> None:
    """Check if path is in blocked list. Raises SecurityError if blocked."""
    for pattern in BLOCKED_PATHS:
        if re.search(pattern, path, re.IGNORECASE):
            raise SecurityError(f"Blocked path access: {path}")


def filter_tool_call(data: dict[str, Any]) -> Optional[dict[str, Any]]:
    """
    Inspect MCP tool call and block if it violates security policies.

    Returns:
        None if the call should pass through
        Error response dict if the call should be blocked
    """
    if data.get("method") != "tools/call":
        return None  # Not a tool call, pass through

    params = data.get("params", {})
    tool_name = params.get("name", "")
    arguments = params.get("arguments", {})

    # Block banned tool names
    if tool_name in BLOCKED_TOOLS:
        return {
            "jsonrpc": "2.0",
            "error": {
                "code": -32000,
                "message": f"Tool '{tool_name}' is blocked by security policy"
            },
            "id": data.get("id")
        }

    # Check for command execution in arguments
    if "command" in arguments:
        try:
            check_command(arguments["command"])
        except SecurityError as e:
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32000, "message": str(e)},
                "id": data.get("id")
            }

    # Check for path access violations
    for path_key in ["path", "file", "filepath", "directory"]:
        if path_key in arguments:
            try:
                check_path(arguments[path_key])
            except SecurityError as e:
                return {
                    "jsonrpc": "2.0",
                    "error": {"code": -32000, "message": str(e)},
                    "id": data.get("id")
                }

    # Block URL fetch to suspicious domains
    if "url" in arguments:
        url = arguments["url"]
        suspicious_domains = [
            "pastebin.com",
            "iplogger.org",
            "grabify.link",
            "bit.ly",  # URL shorteners can hide destination
        ]
        if any(domain in url.lower() for domain in suspicious_domains):
            return {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32000,
                    "message": f"URL domain blocked: {url}"
                },
                "id": data.get("id")
            }

    return None  # Pass through


def main() -> int:
    """Main filter loop."""
    if len(sys.argv) < 2:
        print("Usage: mcp_command_filter.py <mcp-server-cmd> [args...]", file=sys.stderr)
        return 1

    # Start the actual MCP server as a subprocess
    mcp_server_cmd = sys.argv[1:]
    try:
        proc = subprocess.Popen(
            mcp_server_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            text=True,
            bufsize=1,
        )
    except Exception as e:
        print(f"Failed to start MCP server: {e}", file=sys.stderr)
        return 1

    # Filter stdin -> MCP server
    def filter_input():
        for line in sys.stdin:
            try:
                data = json.loads(line)
                error_response = filter_tool_call(data)

                if error_response:
                    # Send error back to agentgateway
                    print(json.dumps(error_response), flush=True)
                    print(f"BLOCKED: {error_response}", file=sys.stderr)
                else:
                    # Pass through to MCP server
                    proc.stdin.write(line)
                    proc.stdin.flush()

            except json.JSONDecodeError:
                # Not JSON, pass through as-is
                proc.stdin.write(line)
                proc.stdin.flush()
            except Exception as e:
                print(f"Filter error: {e}", file=sys.stderr)

    # Forward MCP server output -> stdout
    import threading

    input_thread = threading.Thread(target=filter_input, daemon=True)
    input_thread.start()

    for line in proc.stdout:
        print(line, end='', flush=True)

    proc.wait()
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
