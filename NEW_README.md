# Model Context Protocol (MCP) Server

A Python implementation of the Model Context Protocol server with support for multiple services including Docker, Filesystem, and Email operations.

## Features

- **Docker MCP Server**: Manage Docker containers, images, volumes, and networks
- **Filesystem MCP Server**: Perform file and directory operations
- **Email MCP Server**: Send and manage emails with various providers
- **Webhook MCP Server**: Handle webhook events and callbacks
- **RESTful API**: Modern API design with OpenAPI documentation
- **Modular Architecture**: Easy to extend with new services
- **Environment Configuration**: Centralized configuration using environment variables
- **Logging & Monitoring**: Built-in logging and Prometheus metrics

## Prerequisites

- Python 3.8+
- Docker (for Docker MCP server)
- Node.js 16+ (for some services)
- npm or yarn

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/mcp-server.git
cd mcp-server
```

### 2. Set Up Python Environment

```bash
# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-test.txt  # For development
```

### 3. Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit the .env file with your configuration
# See .env.example for all available options
```

### 4. Install Node.js Dependencies (if needed)

```bash
cd servers
npm install
cd ..
```

## Usage

### Starting the Servers

Start all configured servers with a single command:

```bash
./start_server.sh
```

### Environment Configuration

The following environment variables can be set in the `.env` file:

#### General Configuration
- `HOST`: Server host (default: `0.0.0.0`)
- `PORT`: Main server port (default: `8000`)
- `DEBUG`: Enable debug mode (default: `False`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

#### Docker MCP Server
- `DOCKER_ENABLED`: Enable Docker server (default: `true`)
- `DOCKER_PORT`: Docker server port (default: `8001`)
- `DOCKER_HOST`: Docker daemon socket (default: `unix:///var/run/docker.sock`)

#### Filesystem MCP Server
- `FILESYSTEM_ENABLED`: Enable Filesystem server (default: `true`)
- `FILESYSTEM_PORT`: Filesystem server port (default: `8003`)
- `FILESYSTEM_BASE_PATH`: Base path for filesystem operations (default: `/data`)

#### Email MCP Server
- `EMAIL_ENABLED`: Enable Email server (default: `false`)
- `EMAIL_PORT`: Email server port (default: `8002`)
- `SMTP_SERVER`: SMTP server address
- `SMTP_PORT`: SMTP server port (default: `587`)
- `SMTP_USERNAME`: SMTP username
- `SMTP_PASSWORD`: SMTP password

## API Documentation

Once the servers are running, you can access the API documentation:

- **Main API**: http://localhost:8000/docs
- **Docker API**: http://localhost:8001/docs
- **Filesystem API**: http://localhost:8003/docs
- **Email API**: http://localhost:8002/docs

## Examples

### Docker API Examples

List all containers:
```bash
curl -X POST http://localhost:8001/mcp/docker.containers.list \
  -H "Content-Type: application/json" \
  -d '{"all": true}'
```

Run a container:
```bash
curl -X POST http://localhost:8001/mcp/docker.containers.run \
  -H "Content-Type: application/json" \
  -d '{"image": "nginx:alpine", "detach": true}'
```

### Filesystem API Examples

List directory contents:
```bash
curl -X POST http://localhost:8003/mcp/filesystem.listDirectory \
  -H "Content-Type: application/json" \
  -d '{"path": "/"}'
```

## Development

### Running Tests

```bash
# Install test dependencies
pip install -r requirements-test.txt

# Run all tests
pytest

# Run tests with coverage
pytest --cov=mcp --cov-report=html
```

### Code Style

This project uses:
- Black for code formatting
- isort for import sorting
- Flake8 for linting
- Mypy for type checking

Run the following to format and check your code:

```bash
# Format code
black .

# Sort imports
isort .

# Lint code
flake8

# Type checking
mypy .
```

### Building Documentation

```bash
# Install documentation dependencies
pip install -r docs/requirements.txt

# Build documentation
cd docs
make html
```

## Deployment

### Docker

Build the Docker image:

```bash
docker build -t mcp-server .

# Run the container
docker run -d --name mcp-server \
  -p 8000:8000 \
  -p 8001-8003:8001-8003 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/data:/data \
  --env-file .env \
  mcp-server
```

### Systemd Service

Create a systemd service file at `/etc/systemd/system/mcp-server.service`:

```ini
[Unit]
Description=MCP Server
After=network.target

[Service]
User=mcp
Group=mcp
WorkingDirectory=/path/to/mcp-server
EnvironmentFile=/path/to/mcp-server/.env
ExecStart=/path/to/mcp-server/.venv/bin/uvicorn mcp.main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

Then enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mcp-server
sudo systemctl start mcp-server
```

## Troubleshooting

### Common Issues

1. **Docker Permission Denied**
   Ensure the user running the server has permission to access the Docker daemon:
   ```bash
   sudo usermod -aG docker $USER
   ```

2. **Port Already in Use**
   If you get a port in use error, either stop the process using the port or change the port in the `.env` file.

3. **Missing Dependencies**
   Make sure all dependencies are installed:
   ```bash
   pip install -r requirements.txt
   ```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

MIT
