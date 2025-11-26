# base https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ai/azure-ai-projects/samples/agents/tools/sample_agent_mcp_with_project_connection.py
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
import os

from azure.ai.projects.models import PromptAgentDefinition, MCPTool
from openai.types.responses.response_input_param import McpApprovalResponse, ResponseInputParam
from dotenv import load_dotenv


def _get_agent_instructions() -> str:
    return (
        "You are an AI assistant that provides information about music artists, "
        "their setlists, and concert details using the Setlist.fm API provided by the MCP server. "
        "Use the available functions to fetch accurate and up-to-date information. "
        "Be concise and relevant in your responses. "
        "When providing concert details, include the date, venue, and location of each concert."
        "Always cite the source of your information."
        "When you call function, ensure the arguments are correctly formatted as per the function definition and remove parameters that are not required or that have an empty value."
        "If the value of parameter is blank or empty, do not include it in the function call."
        "Always start by searching for the artist Mdid using the 'searchForArtist' function."
    )


def _process_mcp_approval_requests(response, approved_server_label: str = "setlistfm-mcp-tool") -> list[ResponseInputParam]:
    """
    Process MCP approval requests from the agent response.
    
    Args:
        response: The response from the OpenAI client containing potential MCP approval requests
        approved_server_label: The server label to automatically approve (default: "setlistfm")
        
    Returns:
        List of ResponseInputParam containing approval responses
    """
    input_list: list[ResponseInputParam] = []
    
    for item in response.output:
        print(f"Response Item Type: {item.type}")
        if item.type == "mcp_approval_request":
            if item.server_label == approved_server_label and item.id:
                # Automatically approve the MCP request to allow the agent to proceed
                # In production, you might want to implement more sophisticated approval logic
                print(f"Approving MCP request for server: {item.server_label}, request ID: {item.id}")
                print(f"Approving the call of '{item.name}' with the following arguments: {item.arguments}")
                input_list.append(
                    McpApprovalResponse(
                        type="mcp_approval_response",
                        approve=True,
                        approval_request_id=item.id,
                    )
                )
    
    return input_list

load_dotenv()
print("Setting up AI Project Client")
print("AZURE_AI_AGENT_ENDPOINT:", os.environ.get("AZURE_AI_AGENT_ENDPOINT"))
project_client = AIProjectClient(
    endpoint=os.environ["AZURE_AI_AGENT_ENDPOINT"],
    credential=DefaultAzureCredential(),
)

setlistfm_mcp_url = os.getenv("SETLISTAPI_MCP_ENDPOINT")
print(f"Setting up Setlist FM plugin {setlistfm_mcp_url}")
if not setlistfm_mcp_url:
    print(
        "SETLISTAPI_MCP_ENDPOINT environment variable is not set.")
    raise ValueError(
        "SETLISTAPI_MCP_ENDPOINT must be set in environment variables.")

existing_tool = MCPTool(
        server_label="existing-mcp-tool",
        require_approval="always",
        project_connection_id="setlistfm-mcp-connection", 
        server_url=setlistfm_mcp_url,
        headers={'Ocp-Apim-Subscription-Key': str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))}
        )


agent = project_client.agents.create_version(
        agent_name="SetlistFM-MCP-Agent",
        definition=PromptAgentDefinition(
            model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
            instructions=_get_agent_instructions(),
            tools=[existing_tool],
        ),
    )
print(f"Created agent {agent.name}/{agent.id} using model:", os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"])

openai_client = project_client.get_openai_client()

# Reference the agent to get a response
TASK = "Can you provide details about recent concerts and setlists in 2025 performed by the band Wolf Alice? Provide the average setlist length and the most frequently played songs."
print("Sending request to agent...")
print("TASK:", TASK )
response = openai_client.responses.create(
    input=[{"role": "user", "content": TASK}],
    extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
)


while True:
    # Process any MCP approval requests that were generated
    input_list = _process_mcp_approval_requests(response, approved_server_label=existing_tool.server_label)
    if len(input_list) == 0:
        print("No MCP approval requests to process.")
        print("STOP: ", response.output)
        break
    else:
        print(f"Processed {len(input_list)} MCP approval requests.")
        # Send the approval response back to continue the agent's work
        # This allows the MCP tool to access the SetlistFM servicenand complete the original request
        response = openai_client.responses.create(
            input=input_list,
            previous_response_id=response.id,
            extra_body={"agent": {"name": agent.name, "type": "agent_reference"}},
    )

print(f"Final Response: {response}")
for item in response.output:
    print (item)
    print(f"Response Item Type: {item.type}")
    print(f"Response Item Content: {getattr(item, 'output', None)}")


print(f"=>Final Response: {response.output_text}")

# Clean up resources by deleting the agent version
# This prevents accumulation of unused agent versions in your project
#print(f"Deleting agent version to clean up resources...{agent.name} - {version}")
#project_client.agents.delete_version(agent_name=agent.name, agent_version=version)
#print("Agent deleted")


        