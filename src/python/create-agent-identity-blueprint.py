
#!/usr/bin/env python3

"""
create-agent-identity-blueprint.py - Create an Agent Identity Blueprint in Microsoft Entra ID

This script creates an Agent Identity Blueprint using Microsoft Graph Beta APIs,
assigns a user-assigned managed identity as a federated credential, and creates
OAuth2 permission scopes for A2A agent communication.

Prerequisites:
    - Azure CLI logged in with appropriate permissions (Agent ID Administrator role)
    - Required Graph permissions: AgentIdentityBlueprint.Create,
      AgentIdentityBlueprint.AddRemoveCreds.All, AgentIdentityBlueprint.ReadWrite.All

Usage:
    python create-agent-identity-blueprint.py \\
        --display-name "My Agent Blueprint" \\
        --tenant-id <tenant-id> \\
        --msi-principal-id <managed-identity-principal-id> \\
        [--msi-name <managed-identity-name>]

Example:
    python create-agent-identity-blueprint.py \\
        --display-name "FINBOT Agent Blueprint" \\
        --tenant-id "12345678-1234-1234-1234-123456789012" \\
        --msi-principal-id "87654321-4321-4321-4321-210987654321" \\
        --msi-name "finbot-managed-identity"

Reference:
    https://learn.microsoft.com/en-us/entra/agent-id/identity-platform/create-blueprint
"""

import argparse
import asyncio
import json
import logging
import sys
import uuid
from typing import Any

import httpx
from azure.identity.aio import DefaultAzureCredential

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Microsoft Graph Beta API base URL
GRAPH_BETA_URL = "https://graph.microsoft.com/beta"

# Required scopes for Microsoft Graph
# Use .default to request all permissions the user has consented to
GRAPH_SCOPES = ["https://graph.microsoft.com/.default"]


class AgentIdentityBlueprintCreator:
    """Creates and configures an Agent Identity Blueprint in Microsoft Entra ID."""

    def __init__(
        self,
        tenant_id: str,
        display_name: str,
        msi_principal_id: str,
        msi_name: str = "managed-identity",
        sponsor_user_id: str | None = None,
        owner_user_id: str | None = None,
    ):
        self.tenant_id = tenant_id
        self.display_name = display_name
        self.msi_principal_id = msi_principal_id
        self.msi_name = msi_name
        # Optional explicit sponsor/owner user object IDs. If not provided,
        # the script will resolve the current user and use that ID for both
        # sponsors and owners.
        self.sponsor_user_id = sponsor_user_id
        self.owner_user_id = owner_user_id
        self.credential: DefaultAzureCredential | None = None
        self.http_client: httpx.AsyncClient | None = None
        self.access_token: str | None = None

    async def __aenter__(self):
        """Async context manager entry.

        Uses DefaultAzureCredential so that in local development it will
        pick up your personal `az login` context, while still working with
        other supported credential sources in CI/CD.
        """
        # DefaultAzureCredential will use the Azure CLI context when available
        logger.info(
            "Initializing DefaultAzureCredential (will use az login context if available)"
        )
        self.credential = DefaultAzureCredential()
        self.http_client = httpx.AsyncClient(timeout=60.0)
        # Get access token
        token = await self.credential.get_token(*GRAPH_SCOPES)
        self.access_token = token.token
        logger.info(
            "Successfully acquired Microsoft Graph access token using DefaultAzureCredential"
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.http_client:
            await self.http_client.aclose()
        if self.credential:
            await self.credential.close()

    def _get_headers(self) -> dict[str, str]:
        """Get HTTP headers for Graph API requests."""
        return {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "OData-Version": "4.0",
        }

    async def _make_request(
        self,
        method: str,
        url: str,
        json_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Make an HTTP request to Microsoft Graph API."""
        headers = self._get_headers()

        logger.debug(f"Making {method} request to {url}")
        logger.debug(
            f"Request headers: {json.dumps({k: v if k != 'Authorization' else 'Bearer ***' for k, v in headers.items()}, indent=2)}"
        )
        if json_data:
            logger.debug(f"Request body: {json.dumps(json_data, indent=2)}")

        response = await self.http_client.request(
            method=method,
            url=url,
            headers=headers,
            json=json_data,
        )

        logger.debug(f"Response status: {response.status_code}")
        logger.debug(
            f"Response headers: {json.dumps(dict(response.headers), indent=2)}"
        )
        logger.debug(f"Response body: {response.text}")

        if response.status_code >= 400:
            error_body = response.text
            logger.error(
                f"Request failed with status {response.status_code}: {error_body}"
            )
            raise Exception(
                f"Graph API request failed: {response.status_code} - {error_body}"
            )

        if response.status_code == 204:
            return {}

        return response.json()

    async def _get_current_user_id(self) -> str:
        """Resolve the current user's object ID via Microsoft Graph.

        Uses the v1.0 /me endpoint so that we can bind sponsors/owners
        if explicit IDs are not provided on the command line.
        """
        url = "https://graph.microsoft.com/v1.0/me"
        logger.info("Resolving current user via %s", url)
        result = await self._make_request("GET", url, None)
        user_id = result.get("id")
        if not user_id:
            raise Exception("Failed to resolve current user id from /me response")
        logger.info("Current user details: %s", json.dumps(result, indent=2))
        logger.info("Resolved current user id: %s", user_id)
        return user_id

    async def create_blueprint(self) -> dict[str, Any]:
        """
        Create an Agent Identity Blueprint.

        Returns:
            dict: The created blueprint object containing id, appId, etc.
        """
        logger.info(f"Creating Agent Identity Blueprint: {self.display_name}")

        # Determine sponsor/owner IDs. If not explicitly provided, fall back
        # to the current user resolved via /me.
        sponsor_id = self.sponsor_user_id
        owner_id = self.owner_user_id

        if not sponsor_id and not owner_id:
            logger.info(
                "No sponsor/owner specified; resolving current user and using as both "
                "sponsor and owner."
            )
            current_id = await self._get_current_user_id()
            sponsor_id = current_id
            owner_id = current_id
        else:
            # If only one of sponsor/owner is provided, use it for the other
            # as a reasonable default.
            if sponsor_id and not owner_id:
                owner_id = sponsor_id
            if owner_id and not sponsor_id:
                sponsor_id = owner_id

        logger.info("Using sponsor user id: %s", sponsor_id)
        logger.info("Using owner user id: %s", owner_id)

        # According to the current documentation, agent identity blueprints
        # are created via POST /beta/applications with an @odata.type
        # discriminator of Microsoft.Graph.AgentIdentityBlueprint.
        url = f"{GRAPH_BETA_URL}/applications/"
        body = {
            "@odata.type": "Microsoft.Graph.AgentIdentityBlueprint",
            "displayName": self.display_name,
            "sponsors@odata.bind": [
                f"https://graph.microsoft.com/v1.0/users/{sponsor_id}",
            ],
            "owners@odata.bind": [
                f"https://graph.microsoft.com/v1.0/users/{owner_id}",
            ],
        }

        result = await self._make_request("POST", url, body)
        logger.info(
            f"Created blueprint with id: {result.get('id')}, appId: {result.get('appId')}"
        )
        return result

    async def create_service_principal(self, app_id: str) -> dict[str, Any]:
        """
        Create a service principal for the Agent Identity Blueprint.

        Args:
            app_id: The appId of the created blueprint.

        Returns:
            dict: The created service principal object.
        """
        logger.info(f"Creating service principal for appId: {app_id}")

        url = f"{GRAPH_BETA_URL}/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal"
        body = {
            "appId": app_id,
        }

        result = await self._make_request("POST", url, body)
        logger.info(f"Created service principal with id: {result.get('id')}")
        return result

    async def add_federated_credential(
        self, blueprint_object_id: str
    ) -> dict[str, Any]:
        """
        Add a federated identity credential using a user-assigned managed identity.

        Args:
            blueprint_object_id: The object id of the blueprint application.

        Returns:
            dict: The created federated identity credential object.
        """
        logger.info(
            f"Adding federated credential for managed identity: {self.msi_principal_id}"
        )

        url = f"{GRAPH_BETA_URL}/applications/{blueprint_object_id}/federatedIdentityCredentials"
        body = {
            "name": self.msi_name,
            "issuer": f"https://login.microsoftonline.com/{self.tenant_id}/v2.0",
            "subject": self.msi_principal_id,
            "audiences": ["api://AzureADTokenExchange"],
        }

        result = await self._make_request("POST", url, body)
        logger.info(f"Created federated credential with id: {result.get('id')}")
        return result

    async def configure_scopes(
        self, blueprint_object_id: str, app_id: str
    ) -> dict[str, Any]:
        """
        Configure identifier URI and OAuth2 permission scopes for A2A communication.

        Creates two scopes:
        - A2A.Agent.Chat: For agent-to-agent chat communication
        - A2A.Agent.Admin: For administrative operations on agents

        Args:
            blueprint_object_id: The object id of the blueprint application.
            app_id: The appId of the blueprint.

        Returns:
            dict: The updated application object.
        """
        logger.info("Configuring identifier URI and OAuth2 permission scopes")

        url = f"{GRAPH_BETA_URL}/applications/{blueprint_object_id}"

        # Generate unique GUIDs for each scope
        chat_scope_id = str(uuid.uuid4())
        admin_scope_id = str(uuid.uuid4())

        body = {
            "identifierUris": [f"api://{app_id}"],
            "api": {
                "oauth2PermissionScopes": [
                    {
                        "adminConsentDescription": (
                            "Allow the application to communicate with agents "
                            "for chat operations on behalf of the signed-in user."
                        ),
                        "adminConsentDisplayName": "A2A Agent Chat",
                        "id": chat_scope_id,
                        "isEnabled": True,
                        "type": "User",
                        "value": "A2A.Agent.Chat",
                    },
                    {
                        "adminConsentDescription": (
                            "Allow the application to perform administrative "
                            "operations on agents on behalf of the signed-in user."
                        ),
                        "adminConsentDisplayName": "A2A Agent Admin",
                        "id": admin_scope_id,
                        "isEnabled": True,
                        "type": "User",
                        "value": "A2A.Agent.Admin",
                    },
                ],
            },
        }

        result = await self._make_request("PATCH", url, body)
        logger.info(
            f"Configured scopes - A2A.Agent.Chat (id: {chat_scope_id}), "
            f"A2A.Agent.Admin (id: {admin_scope_id})"
        )
        return result

    async def run(self) -> dict[str, Any]:
        """
        Execute the full blueprint creation workflow.

        Returns:
            dict: Summary of created resources.
        """
        # Step 1: Create the Agent Identity Blueprint
        blueprint = await self.create_blueprint()
        blueprint_object_id = blueprint["id"]
        app_id = blueprint["appId"]

        # Step 2: Create the service principal
        service_principal = await self.create_service_principal(app_id)

        # Step 3: Add federated credential for managed identity
        federated_credential = await self.add_federated_credential(blueprint_object_id)

        # Step 4: Configure identifier URI and OAuth2 scopes
        await self.configure_scopes(blueprint_object_id, app_id)

        summary = {
            "blueprint": {
                "objectId": blueprint_object_id,
                "appId": app_id,
                "displayName": self.display_name,
            },
            "servicePrincipal": {
                "id": service_principal.get("id"),
            },
            "federatedCredential": {
                "id": federated_credential.get("id"),
                "name": self.msi_name,
                "subject": self.msi_principal_id,
            },
            "scopes": [
                "A2A.Agent.Chat",
                "A2A.Agent.Admin",
            ],
            "identifierUri": f"api://{app_id}",
        }

        return summary


async def main_async(args: argparse.Namespace) -> int:
    """Async main function."""
    try:
        async with AgentIdentityBlueprintCreator(
            tenant_id=args.tenant_id,
            display_name=args.display_name,
            msi_principal_id=args.msi_principal_id,
            msi_name=args.msi_name,
            sponsor_user_id=args.sponsor_user_id,
            owner_user_id=args.owner_user_id,
        ) as creator:
            summary = await creator.run()

        print("\n" + "=" * 60)
        print("Agent Identity Blueprint Created Successfully!")
        print("=" * 60)
        print(json.dumps(summary, indent=2))
        print("=" * 60)

        print("\nNext Steps:")
        print(
            f"1. Use the identifier URI 'api://{summary['blueprint']['appId']}' in your agent configuration"
        )
        print("2. Request tokens using the managed identity with the following scopes:")
        print(f"   - api://{summary['blueprint']['appId']}/A2A.Agent.Chat")
        print(f"   - api://{summary['blueprint']['appId']}/A2A.Agent.Admin")
        print("3. Grant admin consent for the scopes if required")

        return 0

    except Exception as e:
        logger.error(f"Failed to create Agent Identity Blueprint: {e}")
        return 1


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Create an Agent Identity Blueprint in Microsoft Entra ID",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Create a blueprint with a managed identity
    python create-agent-identity-blueprint.py \\
        --display-name "FINBOT Agent Blueprint" \\
        --tenant-id "12345678-1234-1234-1234-123456789012" \\
        --msi-principal-id "87654321-4321-4321-4321-210987654321"

    # With custom managed identity name
    python create-agent-identity-blueprint.py \\
        --display-name "FINBOT Agent Blueprint" \\
        --tenant-id "12345678-1234-1234-1234-123456789012" \\
        --msi-principal-id "87654321-4321-4321-4321-210987654321" \\
        --msi-name "finbot-prod-identity"

Required Permissions:
    - Agent ID Administrator or Agent ID Developer role
    - AgentIdentityBlueprint.Create
    - AgentIdentityBlueprint.AddRemoveCreds.All
    - AgentIdentityBlueprint.ReadWrite.All

Reference:
    https://learn.microsoft.com/en-us/entra/agent-id/identity-platform/create-blueprint
        """,
    )

    parser.add_argument(
        "--display-name",
        required=True,
        help="Display name for the Agent Identity Blueprint",
    )
    parser.add_argument(
        "--tenant-id",
        required=True,
        help="Azure AD tenant ID",
    )
    parser.add_argument(
        "--msi-principal-id",
        required=True,
        help="Principal ID (object ID) of the user-assigned managed identity",
    )
    parser.add_argument(
        "--msi-name",
        default="managed-identity",
        help="Name for the federated credential (default: managed-identity)",
    )
    parser.add_argument(
        "--sponsor-user-id",
        help=(
            "Object ID of the user to set as sponsor of the blueprint. "
            "If omitted, the current user (from /me) is used."
        ),
    )
    parser.add_argument(
        "--owner-user-id",
        help=(
            "Object ID of the user to set as owner of the blueprint. "
            "If omitted, the current user (from /me) is used."
        ),
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Set the logging level (default: INFO). DEBUG dumps full HTTP request/response content.",
    )

    args = parser.parse_args()

    # Set logging level
    log_level = getattr(logging, args.log_level.upper(), logging.INFO)
    logging.getLogger().setLevel(log_level)
    logger.setLevel(log_level)

    # Validate required arguments are not empty
    if not args.display_name or not args.display_name.strip():
        parser.error("--display-name cannot be empty")

    if not args.tenant_id or not args.tenant_id.strip():
        parser.error("--tenant-id cannot be empty")

    if not args.msi_principal_id or not args.msi_principal_id.strip():
        parser.error("--msi-principal-id cannot be empty")

    return asyncio.run(main_async(args))


if __name__ == "__main__":
    sys.exit(main())
