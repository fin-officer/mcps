"""Test cases for the MCP API endpoints."""
import os
import json
import unittest
import httpx
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Test configuration
BASE_URL = f"http://{os.getenv('HOST', 'localhost')}:{os.getenv('PORT', '8000')}"
DOCKER_URL = f"http://{os.getenv('HOST', 'localhost')}:{os.getenv('DOCKER_PORT', '8004')}"
EMAIL_URL = f"http://{os.getenv('HOST', 'localhost')}:{os.getenv('EMAIL_PORT', '8005')}"
FILESYSTEM_URL = f"http://{os.getenv('HOST', 'localhost')}:{os.getenv('FILESYSTEM_PORT', '8006')}"

class TestMCPAPI(unittest.IsolatedAsyncioTestCase):
    """Test cases for MCP API endpoints."""
    
    async def asyncSetUp(self):
        """Set up test client."""
        self.client = httpx.AsyncClient()
    
    async def asyncTearDown(self):
        """Close test client."""
        await self.client.aclose()
    
    async def test_health_check(self):
        """Test health check endpoint."""
        response = await self.client.get(f"{BASE_URL}/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
    
    async def test_docker_containers_list(self):
        """Test listing Docker containers."""
        response = await self.client.post(
            f"{DOCKER_URL}/mcp/docker.containers.list",
            json={"all": True}
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("containers", response.json())
    
    async def test_docker_containers_run(self):
        """Test running a Docker container."""
        response = await self.client.post(
            f"{DOCKER_URL}/mcp/docker.containers.run",
            json={
                "image": "nginx:alpine",
                "detach": True,
                "ports": {"80/tcp": 8080}
            }
        )
        self.assertEqual(response.status_code, 200)
        container = response.json()
        self.assertIn("id", container)
        
        # Clean up
        if "id" in container:
            await self.client.post(
                f"{DOCKER_URL}/mcp/docker.containers.remove",
                json={"container_id": container["id"], "force": True}
            )
    
    async def test_filesystem_list_directory(self):
        """Test listing directory contents."""
        response = await self.client.post(
            f"{FILESYSTEM_URL}/mcp/filesystem.listDirectory",
            json={"path": "/"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertIsInstance(response.json(), list)
    
    async def test_filesystem_read_write_file(self):
        """Test reading and writing a file."""
        test_path = "/tmp/test_mcp_file.txt"
        test_content = "Hello, MCP!"
        
        # Write file
        write_response = await self.client.post(
            f"{FILESYSTEM_URL}/mcp/filesystem.writeFile",
            json={
                "path": test_path,
                "content": test_content,
                "encoding": "utf-8"
            }
        )
        self.assertEqual(write_response.status_code, 200)
        
        # Read file
        read_response = await self.client.post(
            f"{FILESYSTEM_URL}/mcp/filesystem.readFile",
            json={"path": test_path, "encoding": "utf-8"}
        )
        self.assertEqual(read_response.status_code, 200)
        self.assertEqual(read_response.json()["content"], test_content)
        
        # Clean up
        await self.client.post(
            f"{FILESYSTEM_URL}/mcp/filesystem.delete",
            json={"path": test_path}
        )

if __name__ == "__main__":
    unittest.main()
