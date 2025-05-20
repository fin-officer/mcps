#!/usr/bin/env python3
"""MCP Server Example."""
import os
import argparse
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def run_docker_server(host: str = "0.0.0.0", port: int = 8000):
    """Run the Docker MCP server."""
    from mcp.servers.docker import create_docker_mcp_server
    
    print(f"Starting Docker MCP Server on http://{host}:{port}")
    server = create_docker_mcp_server()
    server.run(host=host, port=port)

def run_email_server(host: str = "0.0.0.0", port: int = 8001):
    """Run the Email MCP server."""
    from mcp.servers.email import create_email_mcp_server
    
    # Get SMTP configuration from environment variables
    smtp_server = os.getenv("SMTP_SERVER")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_username = os.getenv("SMTP_USERNAME")
    smtp_password = os.getenv("SMTP_PASSWORD")
    
    if not all([smtp_server, smtp_username, smtp_password]):
        raise ValueError("SMTP_SERVER, SMTP_USERNAME, and SMTP_PASSWORD must be set in .env")
    
    print(f"Starting Email MCP Server on http://{host}:{port}")
    server = create_email_mcp_server(smtp_server, smtp_port, smtp_username, smtp_password)
    server.run(host=host, port=port)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MCP Server")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Docker server command
    docker_parser = subparsers.add_parser("docker", help="Run Docker MCP server")
    docker_parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    docker_parser.add_argument("--port", type=int, default=8000, help="Port to listen on")
    
    # Email server command
    email_parser = subparsers.add_parser("email", help="Run Email MCP server")
    email_parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    email_parser.add_argument("--port", type=int, default=8001, help="Port to listen on")
    
    args = parser.parse_args()
    
    if args.command == "docker":
        run_docker_server(args.host, args.port)
    elif args.command == "email":
        run_email_server(args.host, args.port)
    else:
        print(f"Unknown command: {args.command}")
        print("Available commands: docker, email")
