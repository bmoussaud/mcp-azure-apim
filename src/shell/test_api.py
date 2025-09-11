#!/usr/bin/env python3
"""
Python replacement for src/shell/test_api.sh

Behavior:
- Runs `azd env get-values` (falls back to reading .env) and loads environment variables.
- Prints SETLISTAPI_ENDPOINT and SETLISTAPI_SUBSCRIPTION_KEY (like the original script).
- Calls the Setlist.fm API path used in the shell script and pretty-prints JSON response.
"""

from __future__ import annotations
import os
import sys
import subprocess
import argparse
import json
import urllib.request
import urllib.parse
from typing import Optional


def load_azd_env() -> None:
    """
    Populate os.environ with entries from `azd env get-values` output (KEY=VALUE lines).
    If `azd` is not available, tries to read .env in the current directory.
    """
    content = ""
    try:
        content = subprocess.check_output(["azd", "env", "get-values"], stderr=subprocess.STDOUT).decode()
    except FileNotFoundError:
        # azd not installed in environment; fall back to .env file if present
        if os.path.exists(".env"):
            content = open(".env", "r", encoding="utf-8").read()
    except subprocess.CalledProcessError:
        # If azd returns non-zero, still try to read .env
        if os.path.exists(".env"):
            content = open(".env", "r", encoding="utf-8").read()

    for raw in content.splitlines():
        if not raw or raw.strip().startswith("#"):
            continue
        if "=" in raw:
            key, _, val = raw.partition("=")
            val = val.strip().strip('"').strip("'")
            os.environ.setdefault(key.strip(), val)


def build_url(endpoint: str, artist: str, page: int = 1) -> str:
    endpoint = endpoint.rstrip("/")
    query = urllib.parse.urlencode({"artistName": artist, "p": str(page)})
    return f"{endpoint}/1.0/search/setlists?{query}"


def call_api(url: str, subscription_key: str, timeout: Optional[int] = 30) -> tuple[int, bytes, dict]:
    req = urllib.request.Request(url, headers={"Ocp-Apim-Subscription-Key": subscription_key})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        status = resp.getcode()
        body = resp.read()
        headers = dict(resp.getheaders())
    return status, body, headers


def main() -> int:
    parser = argparse.ArgumentParser(description="Call Setlist.fm API using azd-provided env vars.")
    parser.add_argument("--artist", "-a", default="the weeknd", help="Artist name (default: 'the weeknd')")
    parser.add_argument("--page", "-p", type=int, default=1, help="Page number (default: 1)")
    args = parser.parse_args()

    load_azd_env()

    endpoint = os.environ.get("SETLISTAPI_ENDPOINT")
    subscription_key = os.environ.get("SETLISTAPI_SUBSCRIPTION_KEY")

    # Echo variables like the original script
    # print(endpoint or "")
    # print(subscription_key or "")

    if not endpoint or not subscription_key:
        print("Required environment variables SETLISTAPI_ENDPOINT and SETLISTAPI_SUBSCRIPTION_KEY not found.", file=sys.stderr)
        return 2

    url = build_url(endpoint, args.artist, args.page)
    # Print request details (analogous to `set -x` in the shell script)
    # print(f"REQUEST: GET {url}")
    # print(f"HEADER: Ocp-Apim-Subscription-Key: {subscription_key}")

    try:
        status, body, headers = call_api(url, subscription_key)
    except Exception as exc:
        print(f"Request failed: {exc}", file=sys.stderr)
        return 3

    # Try to decode JSON and pretty-print (fallback to raw body on failure)
    try:
        parsed = json.loads(body.decode("utf-8"))
        print(json.dumps(parsed, indent=2, ensure_ascii=False))
    except Exception:
        # If not JSON, print raw response
        print(body.decode("utf-8", errors="replace"))

    return 0 if 200 <= status < 300 else 4


if __name__ == "__main__":
    raise SystemExit(main())