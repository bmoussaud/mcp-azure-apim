docker pull ghcr.io/modelcontextprotocol/inspector:latest
curl -fsSL https://aka.ms/install-azd.sh | bash
cd src/python
uv venv --clear
source .venv/bin/activate
azd env get-values > .env
uv sync