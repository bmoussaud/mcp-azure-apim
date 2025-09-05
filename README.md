cd src/shell
azd env get-values > .env
./test_api.sh

Go the Azure Portal, select the APIM instance and MCP Servers (preview)
Create a MCP Server, expose API as an MCP Server

- API: 'SetList FM'
- API Operations: Search for Artists, Search for Setlists
- Display Name: 'MCP Setlist FM'
- Name: 'mcp-setlist-fm'
- Description: 'Bla'

Get the URL of the MCP Server: `https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp`

cd src/pythpn
uv venv
source .venv/bin/activate^
azd env get-values > .env
uv sync
uv run mcp_client.py
