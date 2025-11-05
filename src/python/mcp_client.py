import asyncio
import os
from dotenv import load_dotenv
from fastmcp.client import Client
from fastmcp.client.transports import StreamableHttpTransport
from render import render_artist_table, render_setlist

load_dotenv()

SETLISTAPI_MCP_ENDPOINT = str(os.getenv("SETLISTAPI_MCP_ENDPOINT"))
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))

# SETLISTAPI_MCP_ENDPOINT = "https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp"
print(f"🔗 Testing connection to {SETLISTAPI_MCP_ENDPOINT}...")

async def main():
    try:
        async with Client(transport=StreamableHttpTransport(
            SETLISTAPI_MCP_ENDPOINT,
            headers={"Ocp-Apim-Subscription-Key": SETLISTAPI_SUBSCRIPTION_KEY},
        ), ) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

            tools = await client.list_tools()
            print(f"🔧 Available tools ({len(tools)}):")
            for tool in tools:
                print(f"   - {tool.name}")
                # print(f"     {tool.description}")
                print(f"     Input Schema: {tool.inputSchema}")

            print("-------" * 18)
            print("🔗 Search for artists with 'Coldplay' in the name")
            searchForArtists = await client.call_tool(
                "searchForArtists", arguments={'artistName': 'Coldplay'}
            )
            artist_payload = searchForArtists.content[0].text if searchForArtists.content else ""
            print(render_artist_table(artist_payload))

            print("-------" * 18)
            artistName = "Linkin Park"
            print(f"🔗 Get a list of setlists for {artistName}")
            searchForSetlists = await client.call_tool(
                "searchForSetlists", arguments={'artistName': artistName, 'p': 1}
            )
            setlist_payload = searchForSetlists.content[0].text if searchForSetlists.content else ""
            print(render_setlist(setlist_payload))
    except Exception as e:
        print(f"❌ failure : {e}")
        raise
    finally:
        print("👋 Closing client...")
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
