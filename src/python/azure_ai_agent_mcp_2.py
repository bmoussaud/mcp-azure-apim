# base https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ai/azure-ai-projects/samples/agents/tools/sample_agent_mcp_with_project_connection.py
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
import os
from azure.ai.projects.models import (PromptAgentDefinition, MCPTool)
from openai.types.responses.response_output_item import McpApprovalRequest, McpListTools
from azure.ai.projects.models import PromptAgentDefinition, MCPTool, Tool
from openai.types.responses.response_input_param import McpApprovalResponse, ResponseInputParam
from dotenv import load_dotenv



load_dotenv()
print("Setting up AI Project Client")
print("PROJECT_ENDPOINT:", os.environ.get("PROJECT_ENDPOINT"))
project_client = AIProjectClient(
    endpoint=os.environ["PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential(),
)

def _get_agent_instructions() -> str:
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


myAgent = "SETLIST"
# Get an existing agent
#agent = project_client.agents.get(agent_name=myAgent)
#print(f"Retrieved agent: {agent.name}")
#print(f"Agent ID: {agent.id}"   )
#print(f"Agent Definition: {agent.versions['latest']}")




setlistfm_mcp_url = os.getenv("SETLISTAPI_MCP_ENDPOINT")
print(f"Setting up Setlist FM plugin {setlistfm_mcp_url}")
if not setlistfm_mcp_url:
    print(
        "SETLISTAPI_MCP_ENDPOINT environment variable is not set.")
    raise ValueError(
        "SETLISTAPI_MCP_ENDPOINT must be set in environment variables.")


mcp_tool = MCPTool(
            server_label="SetlistFMTool",
            server_url=setlistfm_mcp_url,
            require_approval="always",
            project_connection_id="setlistfm",
            headers={'Ocp-Apim-Subscription-Key': str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))})

mcp_tool = MCPTool(
            server_label="setlistfm",
            server_url=setlistfm_mcp_url,
            require_approval="always",
            project_connection_id="setlistfm",
            )

agent_definition = PromptAgentDefinition(
        model=os.environ["MODEL_DEPLOYMENT_NAME"],
        instructions= "", #_get_agent_instructions(),
        tools=[mcp_tool], 
        )

agents_client = project_client.agents
agent = agents_client.create(name="my-mcp-agent-13",definition=agent_definition)

print(f"Created agent: {agent.name}")
print(f"Agent ID: {agent.id}"   )
version = agent.versions['latest'].version
print(f"Agent Definition: {agent.versions['latest']}")

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {version})")

openai_client = project_client.get_openai_client()

# Reference the agent to get a response
response = openai_client.responses.create(
    input=[{"role": "user", "content": "Can you provide details about recent concerts and setlists in 2025 performed by the band Wolf Alice? Provide the average setlist length and the most frequently played songs."}],
    extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
)

 # Process any MCP approval requests that were generated
input_list: ResponseInputParam = []
for item in response.output:
    if item.type == "mcp_approval_request":
        if item.server_label == "setlistfm" and item.id:
            # Automatically approve the MCP request to allow the agent to proceed
            # In production, you might want to implement more sophisticated approval logic
            print(f"Approving MCP request for server: {item.server_label}, request ID: {item.id}")
            #print(item)
            print(f"Approving the call of '{item.name}' with the following arguments: {item.arguments}")
            input_list.append(
                McpApprovalResponse(
                    type="mcp_approval_response",
                    approve=True,
                    approval_request_id=item.id,
                )
            )

print("Final input:")
print(input_list)

# Send the approval response back to continue the agent's work
# This allows the MCP tool to access the GitHub repository and complete the original request
response = openai_client.responses.create(
    input=input_list,
    previous_response_id=response.id,
    extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
)

print(f"Final Response: {response.output_text}")

  # Clean up resources by deleting the agent version
# This prevents accumulation of unused agent versions in your project
print(f"Deleting agent version to clean up resources...{agent.name} - {version}")
project_client.agents.delete_version(agent_name=agent.name, agent_version=version)
print("Agent deleted")


        