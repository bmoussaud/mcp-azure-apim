# mcp-azure-apim

### Configure Azure Resource

This project is using `azd`

```bash
azd auth login
azd provision
```

### Configure MCP Server

Go the Azure Portal, select the APIM instance and MCP Servers (preview)
Create a MCP Server, expose API as an MCP Server

- API: 'SetList FM'
- API Operations: Search for Artists, Search for Setlists, Get a list of an artist's setlists.
- Display Name: 'MCP Setlist FM'
- Name: 'mcp-setlist-fm'

```xml
<set-header name="Authorization" exists-action="override">
    <value>@(context.Request.Headers.GetValueOrDefault("Authorization"))</value>
</set-header>
<set-header name="x-api-key" exists-action="override">
    <value>b5a0cd59c5d84ea7bf80611ddc6ebd71</value>
</set-header>
```

Get the URL of the MCP Server: Example `https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp`

![MCP Azure APIM](img/mcp_azure_apim.png)

### Test API using Shell

```bash
cd src/shell
azd env get-values > .env
./test_api.sh
```

Open mcp.json file
Start the toosl
open a new githup copilot session
promtp:'using the setlistfm tools, give me the setlists of Coldplay'

### Test MCP (Python)

Prepare the environment:

```bash
cd src/python
uv venv
source .venv/bin/activate
azd env get-values > .env
uv sync
```

#### Using MCP Client

`mcp_client.py` uses a library acting as MCP Client. It lists the exposed tools, and call them: `searchForArtists(coldplay)` and `searchForSetlists(Blondshell)`

```bash
uv run mcp_client.py
```

#### Using Agent

`azure_ai_agent_mcp.py` uses the [Semantic Kernel] library to create an [Agent in Azure AI Foundry] configured to use the `SetlistFM MCP Server` as tool.

```bash
uv run azure_ai_agent_mcp.py
```
