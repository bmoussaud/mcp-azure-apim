import asyncio
import os
import sys
from dotenv import load_dotenv
from fastmcp.client import Client
from fastmcp.client.transports import StreamableHttpTransport

load_dotenv()

SETLISTAPI_MCP_ENDPOINT = str(os.getenv("SETLISTAPI_MCP_ENDPOINT"))
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))

# SETLISTAPI_MCP_ENDPOINT = "https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp"
print(f"🔗 Testing connection to {SETLISTAPI_MCP_ENDPOINT}...")


async def main():
    try:
        async with Client(transport=StreamableHttpTransport(
            SETLISTAPI_MCP_ENDPOINT,
            headers={
                "Ocp-Apim-Subscription-Key": SETLISTAPI_SUBSCRIPTION_KEY,
                "mcp-api-key": "your_mcp_api_key"
            }
        ), ) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

        
            # print("🔗 Get a list of setlists for Blondshell")
            for i in range(5):
                print(f"--- Fetching setlists, pass {i+1} ---")
                searchForSetlists = await client.call_tool("searchForSetlists", arguments={'artistName': 'Blondshell'})
            
    except Exception as e:
        print(f"❌ Failure : {e}")
        raise


if __name__ == "__main__":
    asyncio.run(main())
