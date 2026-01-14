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


"""
MCP client for connecting to OAuth-secured mslearn MCP server via Azure APIM gateway.

This module provides a client to interact with the mslearn MCP server that is
secured with OAuth authentication through Azure API Management.
"""



logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MCPMslearnSecuredClient:
    """Client for OAuth-secured mslearn MCP server through Azure APIM gateway."""

    def __init__(
        self,
        gateway_url: Optional[str] = None,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None,
        tenant_id: Optional[str] = None,
        scope: Optional[str] = None,
    ):
        """
        Initialize the secured MCP client.

        Args:
            gateway_url: Azure APIM gateway URL (defaults to MCP_MSLEARN_GATEWAY_URL env var)
            client_id: OAuth client ID (defaults to MCP_MSLEARN_CLIENT_ID env var)
            client_secret: OAuth client secret (defaults to MCP_MSLEARN_CLIENT_SECRET env var)
            tenant_id: Azure AD tenant ID (defaults to MCP_MSLEARN_TENANT_ID env var)
            scope: OAuth scope (defaults to MCP_MSLEARN_SCOPE env var)
        """
        self.gateway_url = gateway_url or os.getenv("MCP_MSLEARN_GATEWAY_URL")
        self.client_id = client_id or os.getenv("MCP_MSLEARN_CLIENT_ID")
        self.client_secret = client_secret or os.getenv("MCP_MSLEARN_CLIENT_SECRET")
        self.tenant_id = tenant_id or os.getenv("MCP_MSLEARN_TENANT_ID")
        self.scope = scope or os.getenv("MCP_MSLEARN_SCOPE", "api://default/.default")

        if not self.gateway_url:
            raise ValueError("MCP_MSLEARN_GATEWAY_URL must be set")
        if not self.client_id or not self.client_secret or not self.tenant_id:
            raise ValueError(
                "OAuth credentials (CLIENT_ID, CLIENT_SECRET, TENANT_ID) must be set"
            )
        
        logger.info("Initialized MCPMslearnSecuredClient with gateway URL: %s", self.gateway_url)
        logger.info("Using Client ID: %s", self.client_id)
        logger.info("Using Tenant ID: %s", self.tenant_id)
        logger.info("Using Scope: %s", self.scope)

        self._access_token: Optional[str] = None
        self._token_expires_at: float = 0.0

    async def _get_access_token(self) -> str:
        """
        Retrieve OAuth access token using client credentials flow.

        Returns:
            Access token string
        """

        # Return cached token if still valid
        if self._access_token and time.time() < self._token_expires_at - 60:
            return self._access_token

        token_url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"

        data = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "scope": self.scope,
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(token_url, data=data)
            response.raise_for_status()
            token_data = response.json()

            self._access_token = token_data["access_token"]
            expires_in = token_data.get("expires_in", 3600)
            self._token_expires_at = time.time() + expires_in

            logger.info("Successfully obtained OAuth access token")
            return self._access_token

    async def list_tools(self) -> List[Dict[str, Any]]:
        """
        List available tools from the MCP server.

        Returns:
            List of tool definitions
        """
        token = await self._get_access_token()
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.gateway_url}/tools", headers=headers, timeout=30.0
            )
            response.raise_for_status()
            return response.json()

    async def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Any:
        """
        Call a tool on the MCP server.

        Args:
            tool_name: Name of the tool to call
            arguments: Tool arguments

        Returns:
            Tool execution result
        """
        token = await self._get_access_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        payload = {"name": tool_name, "arguments": arguments}

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.gateway_url}/tools/call",
                headers=headers,
                json=payload,
                timeout=60.0,
            )
            response.raise_for_status()
            return response.json()

    async def list_resources(self) -> List[Dict[str, Any]]:
        """
        List available resources from the MCP server.

        Returns:
            List of resource definitions
        """
        token = await self._get_access_token()
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.gateway_url}/resources", headers=headers, timeout=30.0
            )
            response.raise_for_status()
            return response.json()


async def main() -> None:
    """Example usage of the secured MCP mslearn client."""
    try:
        client = MCPMslearnSecuredClient()

        logger.info("Listing available tools...")
        tools = await client.list_tools()
        logger.info(f"Available tools: {[t.get('name') for t in tools]}")

        logger.info("Listing available resources...")
        resources = await client.list_resources()
        logger.info(f"Available resources: {len(resources)} found")

        # Example tool call (adjust based on actual mslearn tools)
        # result = await client.call_tool("search_modules", {"query": "azure"})
        # logger.info(f"Tool result: {result}")

    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise


if __name__ == "__main__":
    asyncio.run(main())