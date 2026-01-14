import asyncio
import logging
import os
from typing import Any, Dict, List, Optional
import httpx
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
import time
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


from fastmcp import Client
from fastmcp.client.auth import OAuth

async def main() -> None:

    gateway_url = os.getenv("MCP_MSLEARN_GATEWAY_URL")
    print(f"🔗 Connecting to secured mslearn MCP server at {gateway_url}...")
    oauth = OAuth(mcp_url=gateway_url)

    async with Client(gateway_url, auth=oauth) as client:
        await client.ping()
        print("✅ Successfully authenticated!")
        tools = await client.list_tools()
        print(f"🔧 Available tools ({len(tools)}):")
        for tool in tools:
            print(f"   - {tool.name}")
            print(f"     Input Schema: {tool.inputSchema}")
        print("✅ Successfully authenticated to secured mslearn MCP server!")

if __name__ == "__main__":
    asyncio.run(main())