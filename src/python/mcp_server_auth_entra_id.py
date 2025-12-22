"""Run with: cd servers && uvicorn auth_mcp:app --host 0.0.0.0 --port 8000"""

import asyncio
import logging
import os
import uuid
from datetime import date
from enum import Enum
from typing import Annotated

import logfire
from azure.core.settings import settings

from azure.monitor.opentelemetry import configure_azure_monitor

from dotenv import load_dotenv
from fastmcp import Context, FastMCP
from fastmcp.server.auth import RemoteAuthProvider
from fastmcp.server.auth.providers.azure import AzureProvider
from fastmcp.server.auth.providers.jwt import JWTVerifier
from fastmcp.server.dependencies import get_access_token
from fastmcp.server.middleware import Middleware, MiddlewareContext
from fastmcp.utilities.logging import configure_logging, get_logger

from key_value.aio.stores.memory import MemoryStore
from opentelemetry.instrumentation.starlette import StarletteInstrumentor
from pydantic import AnyHttpUrl
from rich.console import Console
from rich.logging import RichHandler
from starlette.responses import JSONResponse
import uvicorn

from opentelemetry_middleware import OpenTelemetryMiddleware

RUNNING_IN_PRODUCTION = os.getenv("RUNNING_IN_PRODUCTION", "false").lower() == "true"

if not RUNNING_IN_PRODUCTION:
    load_dotenv(override=True)

logging.basicConfig(
    level=logging.WARNING,
    format="%(message)s",
    handlers=[
        RichHandler(
            console=Console(stderr=True),
            show_path=False,
            show_level=False,
            rich_tracebacks=True,
        )
    ],
)
logger = logging.getLogger("ExpensesMCP")
logger.setLevel(logging.INFO)

# Configure Azure SDK OpenTelemetry to use OTEL
settings.tracing_implementation = "opentelemetry"
configure_logging(level="DEBUG", logger=get_logger("oauth_proxy"))

if os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    logger.info("Setting up Azure Monitor instrumentation")
    configure_azure_monitor()

# Configure authentication provider
auth = None
# Azure/Entra ID authentication using AzureProvider
# When running locally, always use localhost for base URL (OAuth redirects need to match)
oauth_client_store = MemoryStore()

# VS Code Dynamic Auth Provider client ID (pre-registered)
VSCODE_CLIENT_IDS = ['d4f80fbc-bfc9-4c81-849f-16ced65f5f0f','d7acbbc6-5aad-4e05-9aa8-e01f3a967f70']
# Validate required environment variables
required_env_vars = [
    "ENTRA_PROXY_AZURE_CLIENT_ID",
    "ENTRA_PROXY_AZURE_CLIENT_SECRET",
    "OAUTH_TENANT_ID",
]
if RUNNING_IN_PRODUCTION:
    required_env_vars.append("ENTRA_PROXY_MCP_SERVER_BASE_URL")

missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

if RUNNING_IN_PRODUCTION:
    entra_base_url = os.environ["ENTRA_PROXY_MCP_SERVER_BASE_URL"]
else:
    entra_base_url = "http://localhost:8000"

logger.info("Client_id: %s", os.environ["ENTRA_PROXY_AZURE_CLIENT_ID"])

auth = AzureProvider(
    client_id=os.environ["ENTRA_PROXY_AZURE_CLIENT_ID"],
    client_secret=os.environ["ENTRA_PROXY_AZURE_CLIENT_SECRET"],
    tenant_id=os.environ["OAUTH_TENANT_ID"],
    base_url=entra_base_url,
    required_scopes=["mcp-access"],
    client_storage=oauth_client_store    
)
logger.info(
    "Using Entra OAuth Proxy for server %s and %s storage", entra_base_url, type(oauth_client_store).__name__
)

# Pre-register VS Code Dynamic Auth Provider client
async def _register_vscode_client():
    """Register VS Code Dynamic Auth Provider as a known client."""
    from mcp.shared.auth import OAuthClientInformationFull
    for VSCODE_CLIENT_ID in VSCODE_CLIENT_IDS:
        await auth.register_client(OAuthClientInformationFull(
            client_id=VSCODE_CLIENT_ID,
            client_name="VS Code Dynamic Auth Provider",
            redirect_uris=[
                "https://vscode.dev/redirect"
            ],
            allowed_redirect_uri_patterns=["https://vscode.dev/redirect"],
            token_endpoint_auth_method="none",  # Public client
        ))
        logger.info(f"Registered VS Code client: {VSCODE_CLIENT_ID}")

# Register VS Code client when the app starts
try:
    logger.info("Registering VS Code Dynamic Auth Provider client...")
    asyncio.run(_register_vscode_client())
    logger.info("VS Code Dynamic Auth Provider client registered.")
except RuntimeError:
    logger.error("Event loop already running, scheduling client registration")
    loop = asyncio.get_event_loop()
    # If event loop is already running, schedule it
    pass

# Middleware to populate user_id in per-request context state
class UserAuthMiddleware(Middleware):
    def _get_user_id(self):
        token = get_access_token()
        if not (token and hasattr(token, "claims")):
            return None
        # Return 'oid' claim if present (for Entra), otherwise fallback to 'sub' (for KeyCloak)
        return token.claims.get("oid", token.claims.get("sub"))

    async def on_call_tool(self, context: MiddlewareContext, call_next):
        user_id = self._get_user_id()
        if context.fastmcp_context is not None:
            context.fastmcp_context.set_state("user_id", user_id)
        return await call_next(context)

    async def on_read_resource(self, context: MiddlewareContext, call_next):
        user_id = self._get_user_id()
        if context.fastmcp_context is not None:
            context.fastmcp_context.set_state("user_id", user_id)
        return await call_next(context)


# Create the MCP server
mcp = FastMCP("SetList FM MCP", auth=auth, middleware=[OpenTelemetryMiddleware("SetListFM_MCP"), UserAuthMiddleware()])

@mcp.tool
async def search_setlists(
    date: Annotated[date, "Date of the expense in YYYY-MM-DD format"],
    artistName: Annotated[str, "Name of the artist to search for"],
    ctx: Context,
):
    """Add a new expense to Cosmos DB."""
    logger.info(f"Searching setlist for artist {artistName} on date {date.isoformat()}")
    return f"Setlist search for {artistName} on {date.isoformat()} is not yet implemented."

@mcp.tool
async def search_artists(ctx: Context, artist_name: Annotated[str, "Name of the artist to search for"]):
    """Search in the Selistify API for an artist by name."""

    try:
        return f"Artist search for {artist_name} is not yet implemented."
    except Exception as e:
        logger.error(f"Error reading expenses: {str(e)}")
        return f"Error: Unable to retrieve expense data - {str(e)}"


@mcp.custom_route("/health", methods=["GET"])
async def health_check(_request):
    """Health check endpoint for service availability."""
    return JSONResponse({"status": "healthy", "service": "mcp-server"})


# Configure Starlette middleware for OpenTelemetry
# We must do this *after* defining all the MCP server routes
app = mcp.http_app()
StarletteInstrumentor.instrument_app(app)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)