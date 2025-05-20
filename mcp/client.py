"""MCP Client for interacting with MCP servers."""
import json
from typing import Any, Dict, Optional, Union, List
import httpx
from pydantic import BaseModel, HttpUrl

class MCPClientError(Exception):
    """Base exception for MCP client errors."""
    pass

class MCPResponse(BaseModel):
    """MCP response model."""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    trace_id: Optional[str] = None

class MCPClient:
    """Client for interacting with MCP servers."""
    
    def __init__(self, base_url: Union[str, HttpUrl], timeout: int = 30):
        """Initialize the MCP client.
        
        Args:
            base_url: Base URL of the MCP server (e.g., 'http://localhost:8000')
            timeout: Request timeout in seconds
        """
        self.base_url = str(base_url).rstrip('/')
        self.timeout = timeout
        self.client = httpx.AsyncClient(timeout=timeout)
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()
    
    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()
    
    async def call(
        self,
        resource_type: str,
        action: str,
        params: Optional[Dict[str, Any]] = None,
        **kwargs
    ) -> MCPResponse:
        """Call an MCP resource.
        
        Args:
            resource_type: Type of the resource (e.g., 'docker.containers')
            action: Action to perform (e.g., 'list', 'run')
            params: Parameters for the action
            **kwargs: Additional arguments to pass to the request
            
        Returns:
            MCPResponse: The response from the server
        """
        url = f"{self.base_url}/mcp/{resource_type}"
        payload = {"action": action}
        
        if params:
            payload["params"] = params
        
        try:
            response = await self.client.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                **kwargs
            )
            response.raise_for_status()
            return MCPResponse(**response.json())
        except httpx.HTTPStatusError as e:
            try:
                error_data = e.response.json()
                return MCPResponse(
                    success=False,
                    error=error_data.get("error", str(e)),
                    trace_id=error_data.get("trace_id")
                )
            except json.JSONDecodeError:
                return MCPResponse(success=False, error=str(e))
        except Exception as e:
            return MCPResponse(success=False, error=str(e))
    
    async def health_check(self) -> Dict[str, Any]:
        """Check the health of the MCP server."""
        try:
            response = await self.client.get(f"{self.base_url}/health")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"status": "error", "error": str(e)}

# Example usage:
"""
async def example():
    # Create a client for the Docker MCP server
    async with MCPClient("http://localhost:8000") as client:
        # Check server health
        health = await client.health_check()
        print(f"Server health: {health}")
        
        # List containers
        response = await client.call(
            resource_type="docker.containers",
            action="list",
            params={"all": True}
        )
        
        if response.success:
            print("Containers:", response.data)
        else:
            print("Error:", response.error)
"""
