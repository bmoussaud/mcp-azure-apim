import asyncio
import os
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
            headers={"x-api-key": SETLISTAPI_SUBSCRIPTION_KEY},
        ), ) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

            tools = await client.list_tools()
            print(f"🔧 Available tools ({len(tools)}):")
            for tool in tools:
                print(f"   - {tool.name}")
                # print(f"     {tool.description}")
                print(f"     Params: {tool.inputSchema}")

            # result = await client.call_tool("get_current_users_profile")
            searchForArtists = await client.call_tool("searchForArtists", arguments={'artistName': 'Coldplay'})
            print(searchForArtists.content[0].text)

            searchForSetlists = await client.call_tool("searchForSetlists", arguments={'artistName': 'Coldplay'})
            print(searchForSetlists.content[0].text)

            # getAListOfAnArtistsSetlists = await client.call_tool("getAListOfAnArtistsSetlists", arguments={'mbid': 'cc197bad-dc9c-440d-a5b5-d52ba2e14234', 'p': 1})
            # print(getAListOfAnArtistsSetlists.content[0].text)

    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        raise
    finally:
        print("👋 Closing client...")
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
