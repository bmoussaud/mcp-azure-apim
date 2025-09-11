docker pull ghcr.io/modelcontextprotocol/inspector:latest
cd src/python
uv venv --clear
source .venv/bin/activate
azd env get-values > .env
uv sync