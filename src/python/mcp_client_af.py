# Copyright (c) Microsoft. All rights reserved.

import os
import asyncio
from dotenv import load_dotenv
from agent_framework import ChatAgent, MCPStreamableHTTPTool
from agent_framework import HostedMCPTool, HostedWebSearchTool, TextReasoningContent, UsageContent
from agent_framework.openai import OpenAIResponsesClient
from agent_framework_azure_ai import AzureAIAgentClient
from azure.identity import DefaultAzureCredential
from agent_framework import HostedMCPTool
"""
MCP Authentication Example

This example demonstrates how to authenticate with MCP servers using API key headers.

For more authentication examples including OAuth 2.0 flows, see:
- https://github.com/modelcontextprotocol/python-sdk/tree/main/examples/clients/simple-auth-client
- https://github.com/modelcontextprotocol/python-sdk/tree/main/examples/servers/simple-auth
"""

load_dotenv()

SETLISTAPI_MCP_ENDPOINT = str(os.getenv("SETLISTAPI_MCP_ENDPOINT"))
SETLISTAPI_MCP_ENDPOINT =" https://learn.microsoft.com/api/mcp"
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))

def _get_agent_instructions() -> str:
    return (
        "You are an AI assistant that provides information about music artists, "
        "their setlists, and concert details using the Setlist.fm API. "
        "Use the available functions to fetch accurate and up-to-date information. "
        "Be concise and relevant in your responses. Use the MCP tools to get the data."
    )

TASK = "Can you provide details about recent concerts and setlists in 2025 performed by the band Wolf Alice? Provide the average setlist length and the most frequently played songs."
#TASK= "Tell me more about storage accounts in Azure."


async def api_key_auth_example() -> None:
    """Example of using API key authentication with MCP server."""
    # Configuration

    ms_learn = HostedMCPTool(
                name="Microsoft Learn MCP",
                url="https://learn.microsoft.com/api/mcp",
            )
    
    
    print("ms_learn tool:", ms_learn)
    
    setlistfm_tool = HostedMCPTool(
        name="Setlistfm MCP",
        url=SETLISTAPI_MCP_ENDPOINT,
        headers={"Ocp-Apim-Subscription-Key": SETLISTAPI_SUBSCRIPTION_KEY},
        approval_mode="never_require"
    )
    print("setlistfm_tool tool:", setlistfm_tool)

    chat_client = AzureAIAgentClient(
            project_endpoint=os.getenv("AZURE_AI_AGENT_ENDPOINT"),
            model_deployment_name=os.getenv("AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"),
            async_credential=DefaultAzureCredential(),
            agent_name="SetListFM Agent",
        )
    
    #await chat_client.setup_azure_ai_observability()
    
    agent = ChatAgent(
        chat_client=chat_client,
       name="Setlist.fm Agent",
        instructions=_get_agent_instructions(),
        tools=[
            setlistfm_tool,
        ],
    )


    print("🤖 Running agent with API key authentication...  ")
    print("TASK:", TASK )
    #result = await agent.run()
    print("Agent: ", end="", flush=True)
    async for chunk in agent.run_stream(TASK):
        for content in chunk.contents:
            if isinstance(content, TextReasoningContent):
                print(f"\033[32m{content.text}\033[0m", end="", flush=True)
            if isinstance(content, UsageContent):
                print(f"\n\033[34m[Usage so far: {content.details}]\033[0m\n", end="", flush=True)
        if chunk.text:
            print(chunk.text, end="", flush=True)



if __name__ == "__main__":
    asyncio.run(api_key_auth_example())