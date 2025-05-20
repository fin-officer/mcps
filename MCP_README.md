# MCP Servers Implementation

This project implements a modular MCP (Model Context Protocol) server framework with example implementations for Docker and Email services.

## Project Structure

```
mcps/
├── mcp/                           # Core MCP framework
│   ├── __init__.py               # Core MCP server and resource registry
│   └── servers/                  # MCP server implementations
│       ├── docker/               # Docker MCP server
│       │   └── __init__.py
│       └── email/                # Email MCP server
│           └── __init__.py
├── main.py                      # Entry point for running MCP servers
├── requirements.txt             # Python dependencies
├── .env.example                # Example environment variables
└── MCP_README.md               # This file
```

## Features

- **Modular Architecture**: Each MCP server is self-contained and can be extended independently
- **Decorator-based API**: Use the `@resource` decorator to expose functions as MCP resources
- **Error Handling**: Built-in error handling and response formatting
- **RESTful API**: Automatic REST API generation for all registered resources
- **Health Check**: Built-in health check endpoint

## Getting Started

1. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run a Docker MCP Server**
   ```bash
   python main.py docker --host 0.0.0.0 --port 8000
   ```

4. **Run an Email MCP Server**
   ```bash
   python main.py email --host 0.0.0.0 --port 8001
   ```

## Example API Usage

### Docker MCP Server

**List Containers**
```bash
curl -X POST http://localhost:8000/mcp/docker.containers.list \
  -H "Content-Type: application/json" \
  -d '{"all": true}'
```

**Run a Container**
```bash
curl -X POST http://localhost:8000/mcp/docker.containers.run \
  -H "Content-Type: application/json" \
  -d '{"image": "nginx:alpine", "detach": true}'
```

### Email MCP Server

**Send an Email**
```bash
curl -X POST http://localhost:8001/mcp/email.send \
  -H "Content-Type: application/json" \
  -d '{
    "to_email": "recipient@example.com",
    "subject": "Test Email",
    "body": "This is a test email from MCP Server"
  }'
```

## Extending with New MCP Servers

1. Create a new module in `mcp/servers/`
2. Define your resource handlers using the `@resource` decorator
3. Create a factory function to initialize and return an `MCPServer` instance
4. Add a new command to `main.py` to run your server

## License

This project is licensed under the MIT License - see the LICENSE file for details.
