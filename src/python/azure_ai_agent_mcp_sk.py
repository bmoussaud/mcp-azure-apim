# Copyright (c) Microsoft. All rights reserved.

import asyncio
import os
from azure.ai.agents.models import McpTool
from azure.identity.aio import AzureCliCredential

from semantic_kernel.agents import AzureAIAgent, AzureAIAgentSettings, AzureAIAgentThread
from semantic_kernel.contents import ChatMessageContent, FunctionCallContent, FunctionResultContent

from dotenv import load_dotenv
import traceback

load_dotenv()
"""
The following sample demonstrates how to create a simple, Azure AI agent that
uses the mcp tool to connect to an mcp server.
"""

TASK = "Can you provide details about recent concerts and setlists in 2025 performed by the band Blondshell?"


async def handle_intermediate_messages(message: ChatMessageContent) -> None:
    for item in message.items or []:
        # traceback.print_stack()
        if isinstance(item, FunctionResultContent):
            print(f"Function Result:> {item.result} for function: {item.name}")
        elif isinstance(item, FunctionCallContent):
            print(
                f"Function Call:> {item.name} with arguments: {item.arguments}")
        else:
            print(f"{item}")


def _get_agent_instructions() -> str:
    return (
        "You are an AI assistant that provides information about music artists, "
        "their setlists, and concert details using the Setlist.fm API. "
        "Use the available functions to fetch accurate and up-to-date information. "
        "Be concise and relevant in your responses."
    )


async def main() -> None:
    async with (
        AzureCliCredential() as creds,
        AzureAIAgent.create_client(credential=creds) as client,
    ):

        setlistfm_mcp_url = os.getenv("SETLISTAPI_MCP_ENDPOINT")
        print(f"Setting up Setlist FM plugin {setlistfm_mcp_url}")
        if not setlistfm_mcp_url:
            print(
                "SETLISTAPI_MCP_ENDPOINT environment variable is not set.")
            raise ValueError(
                "SETLISTAPI_MCP_ENDPOINT must be set in environment variables.")

        # 1. Define the MCP tool with the server URL
        mcp_tool = McpTool(
            server_label="setlisftfm",
            server_url=setlistfm_mcp_url,
            allowed_tools=[],  # Specify allowed tools if needed
        )

        # Optionally you may configure to require approval
        # Allowed values are "never" or "always"

        mcp_tool.update_headers(
            "Ocp-Apim-Subscription-Key", str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY")))
        mcp_tool.update_headers(
            "Authorization", f"Bearer {str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))}")
        mcp_tool.set_approval_mode("never")

        print(f"MCP Tool configured with HEADERs: {mcp_tool.headers}")
        print(f"MCP Tool resources: {mcp_tool.resources}")
        # 2. Create an agent with the MCP tool on the Azure AI agent service
        agent_definition = await client.agents.create_agent(
            model=AzureAIAgentSettings().model_deployment_name,
            tools=mcp_tool.definitions,
            instructions=_get_agent_instructions(),
        )

        # 3. Create a Semantic Kernel agent for the Azure AI agent
        agent = AzureAIAgent(
            client=client,
            definition=agent_definition,
        )

        # 4. Create a thread for the agent
        # If no thread is provided, a new thread will be
        # created and returned with the initial response
        thread: AzureAIAgentThread | None = None

        try:
            print(f"# User: '{TASK}'")
            # 5. Invoke the agent for the specified thread for response
            async for response in agent.invoke(
                messages=TASK, thread=thread, on_intermediate_message=handle_intermediate_messages, tools=mcp_tool.definitions
            ):
                print(f"#####################################")
                print(f"# Agent: {response}")
                thread = response.thread
        finally:
            # 6. Cleanup: Delete the thread, agent, and file
            await thread.delete() if thread else None
            await client.agents.delete_agent(agent.id)


if __name__ == "__main__":
    asyncio.run(main())
