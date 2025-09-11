# Copilot / AI Assistant Instructions for the mcp-azure-apim repository

Purpose

- Provide concise, actionable guidance to the AI about the repository structure, goals, coding styles, and safety/security constraints so suggested code changes are consistent with the project.

Project summary

- This repository deploys an Azure API Management (APIM) backed integration for MCP (music/metadata) services and supporting infra and clients.
- Primary areas:
  - Infrastructure-as-Code: [`infra/main.bicep`](infra/main.bicep) and modules under [`infra/modules/`](infra/modules/)
  - APIM resources & policies: [`infra/modules/apim/v1/`](infra/modules/apim/v1/) and API policy XML under [`src/apim/`](src/apim/)
  - Python clients and agents: [`src/python/`](src/python/)
  - Test utilities and scripts: [`src/shell/`](src/shell/)

Languages & tooling

- Bicep for infra (authoritative). Files: [`infra/main.bicep`](infra/main.bicep), e.g. [`infra/modules/apim/v1/apim.bicep`](infra/modules/apim/v1/apim.bicep).
- XML for APIM policies. Example: [`src/apim/setlistfm/mcp-policy-setlistfm.xml`](src/apim/setlistfm/mcp-policy-setlistfm.xml).
- Python for runtime/client code. Entry points and libs in [`src/python/`](src/python/) (see `pyproject.toml`).
- Shell / small scripts for testing in [`src/shell/`](src/shell/).

High-level guidance for generated code

- Respect idempotency and declarative style for infra:
  - For Bicep: prefer parameters, module reuse, clear outputs, and stable resource names that derive from parameters and environment.
  - Do not hard-code secrets in templates; use Key Vault references and parameters. (If a change requires secret use, signal and add a secure parameter instead.)
- For APIM policies:
  - Preserve the canonical policy structure (`<policies>`, `<inbound>`, `<backend>`, `<outbound>`, `<on-error>`).
  - Use `<base />` where the repository or environment expects layering.
  - Keep expressions consistent with APIM policy expressions (C#-like `@( ... )`) and avoid injecting raw secrets into XML.
  - Example existing policy to mirror: [`src/apim/setlistfm/mcp-policy-setlistfm.xml`](src/apim/setlistfm/mcp-policy-setlistfm.xml) (contains `rate-limit-by-key` using `mcp-api-key` header).
- For Python:
  - Use type hints, small focused functions, and logging (prefer `logging` over print).
  - Reuse existing modules: e.g., [`src/python/mcp_client.py`](src/python/mcp_client.py) and agent files.
  - Prefer unit tests with `pytest`. Keep tests fast and deterministic; mock external network calls.
- For shell / test scripts:
  - Keep them minimal and idempotent; use `set -euo pipefail` and check for required env vars.

Repository-specific conventions

- Naming and placement:
  - Keep Bicep modules in `infra/modules/` and reference from `infra/main.bicep`.
  - API-specific policy XML lives under `src/apim/<api-name>/`.
  - Python packages under `src/python/` and configured via `pyproject.toml`.
- When changing an API/policy name or endpoint:
  - Update both infra module(s) and the corresponding `src/apim/*` policy/openapi files to stay in sync.
- When modifying an APIM policy that contains expressions or keys (e.g., `mcp-api-key` header), do not replace the header name without searching repo for usages.

Security and secrets

- Never place secrets or production keys in code or policy files. Use parameterization or Key Vault.
- Add or reference Key Vault secrets in Bicep rather than inlined values.
- If asked to implement vault integration, clearly state the required secure inputs and how callers should provide them.

Testing & validation

- For Bicep changes: include an ARM/Bicep compilation check and, where feasible, a small deployment plan via ARM/Bicep (in PR guidance).
- For APIM policy changes: recommend validating XML and a synthetic request test using `src/shell/test_api.sh` or `src/shell/test_api.py`.
- For Python changes: include unit tests in `tests/` (create if missing) and run `pytest`.

Code generation rules (must-follow)

- Keep diffs minimal and narrowly scoped. When adding a feature, create or update tests + docs.
- Prefer small helper functions over long monoliths; keep single-responsibility.
- Always run static checks in suggestions:
  - For Python: use `pyproject.toml` settings if present (flake/black/isort preferences).
  - For Bicep/ARM: follow resource naming conventions used in the repository.
- When proposing cross-file changes (e.g., rename a resource), list all files to update and include the edits in the same patch.
- Add or update README or a short `CHANGELOG` entry for non-trivial features.

Commit & PR guidance

- Commit message format: `<area>(<scope>): <short description>` (e.g., `infra(apim): add parameter for certificate`) followed by a 1–2 line body if needed.
- Include a short PR description summarizing intent, infra impact, and any manual steps required.

What to avoid

- Don't modify production values / secrets inline.
- Don't assume runtime environment unless documented in the repo (ask user).
- Avoid generating untested infra changes without a plan for validation in PR description.

Useful file references

- Root Azure intent / meta: [`azure.yaml`](azure.yaml)
- Bicep main: [`infra/main.bicep`](infra/main.bicep)
- APIM module example: [`infra/modules/apim/v1/apim.bicep`](infra/modules/apim/v1/apim.bicep)
- Specific APIM policy to mirror: [`src/apim/setlistfm/mcp-policy-setlistfm.xml`](src/apim/setlistfm/mcp-policy-setlistfm.xml)
- Python agent and clients: [`src/python/azure_ai_agent_mcp.py`](src/python/azure_ai_agent_mcp.py), [`src/python/mcp_client.py`](src/python/mcp_client.py)
- Test helpers: [`src/shell/test_api.sh`](src/shell/test_api.sh), [`src/shell/test_api.py`](src/shell/test_api.py)

If you will make changes

- Provide a short plan (1–3 steps) before modifying infra or Azure Functions/Static Web Apps.
- Include tests and/or a validation plan with the PR.
- For any Azure-related code generation, prefer parameterization and note deployment risks.

Contact the user for clarification when:

- A secret or credential is required to complete a task.
- A proposed infra change may impact production.
- Multiple viable designs exist — present options with trade-offs and ask the user which to implement.

Azure tooling rules

- Always call `azure_development-summarize_topic` before starting any Azure-related task. Provide a concise intent string describing the work (e.g., "add APIM policy to support X").
- Before generating Azure code (Bicep, ARM, Function apps, Static Web Apps, etc.) call `get_bestpractices` with `resource = "general"` and `action = "code-generation"` and follow the returned recommendations.
- Before preparing or executing deployments to Azure, call `get_bestpractices` with `resource = "general"` and `action = "deployment"`.
- For Azure Functions-specific code or deployment plans, call `get_bestpractices` with `resource = "azurefunctions"` and `action = "code-generation"` or `action = "deployment"` as appropriate, and follow the plan-first rule.
- When authoring Bicep modules prefer existing verified modules. Use `azure_bicep-get_azure_verified_module` to discover and reuse Azure Verified Modules for each resource type instead of authoring raw resource schemas when available.
- When producing or suggesting Azure CLI commands programmatically, use `azure_cli-generate_azure_cli_command` to generate the commands rather than inventing them manually.
