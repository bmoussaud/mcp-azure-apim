#!/bin/bash
# Pre-provision hook to set up Azure/Entra ID app registration for FastMCP Entra OAuth Proxy


echo "Setting up Entra ID app registration for FastMCP Entra OAuth Proxy..."
python ./infra/auth_init.py
