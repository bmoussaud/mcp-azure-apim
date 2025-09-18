import asyncio
import os
from dotenv import load_dotenv
from fastmcp.client import Client
from fastmcp.client.transports import StreamableHttpTransport
from fastmcp.client.auth import OAuth

load_dotenv()

oauth = OAuth(mcp_url="https://fastmcp.cloud/mcp")

SETLISTAPI_MCP_ENDPOINT = str(os.getenv("SETLISTAPI_MCP_ENDPOINT"))
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))

# SETLISTAPI_MCP_ENDPOINT = "https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp"
print(f"🔗 Testing connection to {SETLISTAPI_MCP_ENDPOINT}...")

async def azure_default_credential_token():
    print("Using DefaultAzureCredential")
    from azure.identity import DefaultAzureCredential, AzureDeveloperCliCredential
    credential = DefaultAzureCredential()
    scope = f"api://{os.getenv("OAUTH_APP_ID")}/.default"
    access_token = credential.get_token(scope)
    return access_token.token

async def azure_client_secret_credential_token():
    print("Using ClientSecretCredential")
    from azure.identity import ClientSecretCredential
    client_id = os.getenv("OAUTH_APP_ID")
    client_secret = os.getenv("OAUTH_CLIENT_SECRET") # az ad app credential reset --id xxxxxxx
    tenant_id = os.getenv("OAUTH_TENANT_ID") 
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    scope = f"api://{os.getenv("OAUTH_APP_ID")}/.default"
    access_token = credential.get_token(scope)
    return access_token.token

async def msal_token():
    print("Using MSAL ConfidentialClientApplication")
    from msal import ConfidentialClientApplication
    scope = f"api://{os.getenv("OAUTH_APP_ID")}/.default"
    client_id = os.getenv("OAUTH_APP_ID")
    client_secret = os.getenv("OAUTH_CLIENT_SECRET")
    tenant_id = os.getenv("OAUTH_TENANT_ID") 
    app = ConfidentialClientApplication(
        client_id,
        client_credential=client_secret,
        authority=f"https://login.microsoftonline.com/{tenant_id}"
    )

    result = app.acquire_token_for_client(scopes=[scope])
    return result.get("access_token")   


async def main(access_token: str):
    try:
        async with Client(transport=StreamableHttpTransport(
            SETLISTAPI_MCP_ENDPOINT,
            headers={"Authorization": f"Bearer {access_token}"},
        ), ) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

            tools = await client.list_tools()
            print(f"🔧 Available tools ({len(tools)}):")
            for tool in tools:
                print(f"   - {tool.name}")
                # print(f"     {tool.description}")
                print(f"     Input Schema: {tool.inputSchema}")

            # result = await client.call_tool("get_current_users_profile")
            print("🔗 Search for artists with 'Coldplay' in the name")
            searchForArtists = await client.call_tool("searchForArtists", arguments={'artistName': 'Coldplay'})
            #print(searchForArtists.content[0].text)

            # print("🔗 Get a list of setlists for Blondshell")
            searchForSetlists = await client.call_tool("searchForSetlists", arguments={'artistName': 'Wolf Alice', 'p': 1})
            print(searchForSetlists.content[0].text)
    except Exception as e:
        print(f"❌ failure : {e}")
        raise
    finally:
        print("👋 Closing client...")
        await client.close()


if __name__ == "__main__":
    # check the arguments to choose the token method
    import sys
    if len(sys.argv) > 1:
        method = sys.argv[1]
        if method == "default_credential":
            access_token = asyncio.run(azure_default_credential_token())
        elif method == "client_secret":
            access_token = asyncio.run(azure_client_secret_credential_token())
        elif method == "msal":
            access_token = asyncio.run(msal_token())
        else:
            print("Unknown method. Use 'default_credential', 'client_secret' or 'msal'.")
            sys.exit(1)
    else:
        print("No method provided. Use 'default', 'client_secret' or 'msal'.")
        sys.exit(1)

    asyncio.run(main(access_token))
