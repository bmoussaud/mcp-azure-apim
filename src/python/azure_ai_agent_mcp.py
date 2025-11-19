# Copyright (c) Microsoft. All rights reserved.

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects import AIProjectClient
import asyncio
import os
import time

from azure.identity.aio import AzureCliCredential
from azure.ai.agents import (
    ListSortOrder,
    McpTool,
    RequiredMcpToolCall,
    SubmitToolApprovalAction,
    ToolApproval, RunStepToolCallDetails
)

# from semantic_kernel.agents import AzureAIAgent, AzureAIAgentSettings, AzureAIAgentThread
# from semantic_kernel.contents import ChatMessageContent, FunctionCallContent, FunctionResultContent

from dotenv import load_dotenv
import traceback

load_dotenv()
"""
The following sample demonstrates how to create a simple, Azure AI agent that
uses the mcp tool to connect to an mcp server.
"""

TASK = "Can you provide details about recent concerts and setlists in 2025 performed by the band Wolf Alice? Provide the average setlist length and the most frequently played songs."


def _get_agent_instructions() -> str:
    return ""

def _get_agent_instructions___() -> str:
    return (
        "You are an AI assistant that provides information about music artists, "
        "their setlists, and concert details using the Setlist.fm API provided by the MCP server. "
        "Use the available functions to fetch accurate and up-to-date information. "
        "Be concise and relevant in your responses. "
        "When providing concert details, include the date, venue, and location of each concert."
        "Always cite the source of your information."
        "When you call function, ensure the arguments are correctly formatted as per the function definition and remove parameters that are not required or that have an empty value."
        "Always start by searching for the artist using the 'search_artist' function."
           
    )


print("Setting up AI Project Client")
print("PROJECT_ENDPOINT:", os.environ.get("PROJECT_ENDPOINT"))
project_client = AIProjectClient(
    endpoint=os.environ["PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential(),
)

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
# mcp_tool.set_approval_mode("never")


async def azure_default_credential_token():
    print("Using DefaultAzureCredential")
    from azure.identity import DefaultAzureCredential
    credential = DefaultAzureCredential()
    scope = f"api://{os.getenv("OAUTH_APP_ID")}/.default"
    access_token = credential.get_token(scope)
    print(f"Access token acquired: {access_token.token}")
    return access_token.token


async def main() -> None:
    with project_client:
        agents_client = project_client.agents

        print(f"MCP Tool resources: {mcp_tool.resources}")
        mcp_tool.update_headers(
            "Ocp-Apim-Subscription-Key", str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY")))
        mcp_tool.update_headers("Authorization", f"Bearer {await azure_default_credential_token()}")

        use_existing_agent=True
        if use_existing_agent:
            myAgent = "SETLIST"
            # Get an existing agent
            agent = project_client.agents.get(agent_name=myAgent)
            print(f"Using existing agent with ID: {agent.id}")
        else:
        # Create a new agent.
        # NOTE: To reuse existing agent, fetch it with get_agent(agent_id)
            agent = agents_client.create_agent(
                model=os.environ["MODEL_DEPLOYMENT_NAME"],
                name="my-mcp-agent",
                instructions=_get_agent_instructions(),
                tools=mcp_tool.definitions,
            )
        # [END create_agent_with_mcp_tool]

        print(f"Created agent, ID: {agent.id}")
        print(f"MCP Server: {mcp_tool.server_label} at {mcp_tool.server_url}")

        # Create thread for communication
        thread = agents_client.threads.create()
        print(f"Created thread, ID: {thread.id}")

        print(f"Posting task to agent: {TASK}")
        # Create message to thread
        message = agents_client.messages.create(
            thread_id=thread.id,
            role="user",
            content=TASK,
        )
        print(f"Created message, ID: {message.id}")

        # [START handle_tool_approvals]
        # Create and process agent run in thread with MCP tools
        run = agents_client.runs.create(
            thread_id=thread.id, agent_id=agent.id, tool_resources=mcp_tool.resources)
        print(f"Created run, ID: {run.id}")

        while run.status in ["queued", "in_progress", "requires_action"]:
            time.sleep(1)
            run = agents_client.runs.get(thread_id=thread.id, run_id=run.id)

            if run.status == "requires_action" and isinstance(run.required_action, SubmitToolApprovalAction):
                tool_calls = run.required_action.submit_tool_approval.tool_calls
                if not tool_calls:
                    print("No tool calls provided - cancelling run")
                    agents_client.runs.cancel(
                        thread_id=thread.id, run_id=run.id)
                    break

                tool_approvals = []
                for tool_call in tool_calls:
                    if isinstance(tool_call, RequiredMcpToolCall):
                        try:
                            print(
                                f"Approving tool call: {tool_call.type}/{tool_call.server_label}/{tool_call.name}")
                            print(f" with inputs: {tool_call.arguments}")
                            tool_approvals.append(
                                ToolApproval(
                                    tool_call_id=tool_call.id,
                                    approve=True,
                                    headers=mcp_tool.headers,
                                )
                            )
                        except Exception as e:
                            print(
                                f"Error approving tool_call {tool_call.id}: {e}")

                # print(f"Tool_approvals: {tool_approvals}")
                if tool_approvals:
                    agents_client.runs.submit_tool_outputs(
                        thread_id=thread.id, run_id=run.id, tool_approvals=tool_approvals
                    )

            print(f"Current run status: {run.status}")
            # [END handle_tool_approvals]

        print(f"Run completed with status: {run.status}")
        if run.status == "failed":
            print(f"Run failed: {run.last_error}")

        # Display run steps and tool calls
        run_steps = agents_client.run_steps.list(
            thread_id=thread.id, run_id=run.id)

        # Loop through each step
        for step in run_steps:
            print(f"Step {step['id']} status: {step['status']}")

            # Check if there are tool calls in the step details
            step_details = step.get("step_details", {})
            if isinstance(step_details, RunStepToolCallDetails):
                for call in step_details.tool_calls:
                    print(f" Tool Call ID: {call.id}")
                    print(
                        f" Type: {call.type}/{call.get('server_label')}/{call.get('name')}")
                    print(f" inputs: {call.get('arguments')}")

            print()  # add an extra newline between steps

        # Fetch and log all messages
        messages = agents_client.messages.list(
            thread_id=thread.id, order=ListSortOrder.ASCENDING)
        print("\nConversation:")
        print("-" * 50)
        for msg in messages:
            if msg.text_messages:
                last_text = msg.text_messages[-1]
                print(f"{msg.role.upper()}: {last_text.text.value}")
                print("-" * 50)

        # Clean-up and delete the agent once the run is finished.
        # NOTE: Comment out this line if you plan to reuse the agent later.
        agents_client.delete_agent(agent.id)
        print("Deleted agent")


if __name__ == "__main__":
    asyncio.run(main())
