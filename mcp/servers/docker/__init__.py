"""Docker MCP Server implementation."""
from typing import Dict, Any, List, Optional
import docker
from docker.models.containers import Container
from docker.models.images import Image
from docker.errors import DockerException, APIError

from mcp import resource, MCPError, MCPServer

class DockerMCP:
    """Docker MCP server implementation."""
    
    def __init__(self):
        try:
            self.client = docker.from_env()
            # Test the connection
            self.client.ping()
        except DockerException as e:
            raise MCPError(f"Failed to initialize Docker client: {str(e)}")
    
    @resource("docker.containers.list")
    async def list_containers(self, all: bool = False, **filters) -> List[Dict[str, Any]]:
        """List containers."""
        try:
            containers = self.client.containers.list(all=all, filters=filters)
            return [{
                'id': c.id,
                'name': c.name,
                'status': c.status,
                'image': c.image.tags[0] if c.image.tags else c.image.id,
                'created': c.attrs['Created']
            } for c in containers]
        except APIError as e:
            raise MCPError(f"Docker API error: {str(e)}")
    
    @resource("docker.containers.run")
    async def run_container(
        self,
        image: str,
        command: str = None,
        detach: bool = True,
        **kwargs
    ) -> Dict[str, Any]:
        """Run a container."""
        try:
            container = self.client.containers.run(
                image=image,
                command=command,
                detach=detach,
                **kwargs
            )
            return {
                'id': container.id,
                'status': container.status,
                'logs': container.logs().decode('utf-8') if not detach else None
            }
        except APIError as e:
            raise MCPError(f"Failed to run container: {str(e)}")
    
    @resource("docker.images.list")
    async def list_images(self, name: str = None, all: bool = False, **filters) -> List[Dict[str, Any]]:
        """List Docker images."""
        try:
            images = self.client.images.list(name=name, all=all, filters=filters)
            return [{
                'id': img.id,
                'tags': img.tags,
                'created': img.attrs['Created'],
                'size': img.attrs['Size']
            } for img in images]
        except APIError as e:
            raise MCPError(f"Failed to list images: {str(e)}")
    
    @resource("docker.images.pull")
    async def pull_image(self, repository: str, tag: str = "latest") -> Dict[str, Any]:
        """Pull a Docker image."""
        try:
            image = self.client.images.pull(repository, tag=tag)
            return {
                'id': image.id,
                'tags': image.tags,
                'created': image.attrs['Created']
            }
        except APIError as e:
            raise MCPError(f"Failed to pull image: {str(e)}")

def create_docker_mcp_server() -> MCPServer:
    """Create and configure a Docker MCP server."""
    server = MCPServer("Docker MCP Server", "1.0.0")
    docker_mcp = DockerMCP()
    return server
