import asyncio
import base64
import json
import os
from dotenv import load_dotenv
from fastmcp.client import Client
from fastmcp.client.auth.oauth import OAuth
from render import render_artist_table, render_setlist

load_dotenv()

SETLISTAPI_MCP_ENDPOINT = "http://localhost:8000/mcp"
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))
print(f"🔗 Testing connection to {SETLISTAPI_MCP_ENDPOINT}...")

async def azure_client_secret_credential_token():
    print("Using ClientSecretCredential")
    from azure.identity import ClientSecretCredential
    client_id = os.getenv("FASTMCP_CLIENT_APP_ID")
    client_secret = os.getenv("FASTMCP_CLIENT_CLIENT_SECRET")
    tenant_id = os.getenv("OAUTH_TENANT_ID")
    
    print(f"Using Client ID: {client_id}")
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    
    # Must use .default for client credential flow
    server_app_id = os.getenv("FASTMCP_SERVER_APP_ID")
    print(f"Client ID: {client_id}")
    print(f"Server ID: {server_app_id}")
    
    # Request token for the SERVER's API
    scope = f"api://{server_app_id}/.default"
    
    print(f"Requesting token for scope: {scope}")
    access_token = credential.get_token(scope)
    return access_token.token

async def azure_default_credential_token():
    print("Using DefaultAzureCredential")
    from azure.identity import DefaultAzureCredential, AzureCliCredential
    credential = AzureCliCredential()
    client_id = os.getenv("ENTRA_PROXY_AZURE_CLIENT_ID", "")
   
    scope = f"api://{client_id}/.default"
    print(f"Requesting token for scope: {scope}")
    access_token = credential.get_token(scope)
    return access_token.token

async def get_user_token_from_cli():
    """Get token for authenticated user from Azure CLI"""
    from azure.identity import AzureCliCredential
    
    credential = AzureCliCredential()
    server_app_id = os.getenv("FASTMCP_SERVER_APP_ID")
    scope = f"api://{server_app_id}/.default"
    
    token = credential.get_token(scope)
    return token.token

def client_oauth(access_token: str):
    print("👋 Starting client...")
    print(f"Using OAUTH")
    return Client("http://localhost:8000/mcp", auth="oauth")

def client_token(access_token: str):
    print("👋 Starting client...")
    print(f"Using access token: {access_token}")
    decode_token(access_token)
    config= {
            "mcpServers": {
            "setlist": {
                    "transport": "streamable-http",  # "http" or "sse" 
                    "url": "http://localhost:8000/mcp",
                    "headers": {"Authorization": f"Bearer {access_token}"},
                },
            }
        }
    auth = OAuth(mcp_url="http://localhost:8000/mcp",client_name="MCP Client Auth Entra ID",callback_port=61382)
    return Client(config, auth=None)

async def main(access_token: str):
    try:
        async with client_token(access_token) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

            tools = await client.list_tools()
            print(f"🔧 Available tools ({len(tools)}):")
            for tool in tools:
                print(f"   - {tool.name}")
                # print(f"     {tool.description}")
                print(f"     Input Schema: {tool.inputSchema}")

            user_info = await client.call_tool("get_user_info")
            print(f"User Info: {user_info}")
            import sys
            sys.exit(1)

            print("🔗 Search for artists with 'Coldplay' in the name")
            searchForArtists = await client.call_tool(
                "getArtists", arguments={'artistName': 'Coldplay'}
            )
            #print(searchForArtists)
            print(render_artist_table(searchForArtists.content[0].text))

            print("🔗 Get a list of setlists for Wolf Alice")
            searchForSetlists = await client.call_tool("getSetlists", arguments={'artistName': 'Wolf Alice', 'p': 1})
            print(render_setlist(searchForSetlists.content[0].text))
    except Exception as e:
        print(f"❌ failure : {e}")
        raise
    finally:
        print("👋 Closing client...")
        await client.close()

def decode_token(token: str):
    """Decode and print JWT token claims"""
    parts = token.split('.')
    if len(parts) != 3:
        print("Invalid token format")
        return
    
    # Decode payload (add padding if needed)
    payload = parts[1]
    payload += '=' * (4 - len(payload) % 4)
    decoded = base64.urlsafe_b64decode(payload)
    claims = json.loads(decoded)
    
    print("🔍 Token Claims:")
    print(f"  aud (audience): {claims.get('aud')}")
    print(f"  azp (audience): {claims.get('azp')}")
    print(f"  iss (issuer): {claims.get('iss')}")
    print(f"  scp (scopes): {claims.get('scp', 'None')}")
    print(f"  azpacr (azpacr): {claims.get('azpacr', 'None')}")
    print(f"  roles: {claims.get('roles', 'None')}")
    print(f"  oid (object id): {claims.get('oid', 'None')}")
    print(f"  appid: {claims.get('appid', 'None')}")
    return claims

if __name__ == "__main__":
    # check the arguments to choose the token method
    access_token = asyncio.run(get_user_token_from_cli())
    asyncio.run(main(access_token))
