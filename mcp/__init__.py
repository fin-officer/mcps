"""Model Context Protocol (MCP) Server Framework."""
from typing import Any, Callable, Dict, List, Optional, TypeVar, Union
from functools import wraps
from fastapi import FastAPI, HTTPException, Request, Depends
from pydantic import BaseModel
import logging
from loguru import logger

# Type variable for generic function typing
F = TypeVar('F', bound=Callable[..., Any])

class MCPError(Exception):
    """Base exception for MCP-related errors."""
    pass

class ResourceRegistry:
    """Registry for MCP resources and their handlers."""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._resources = {}
        return cls._instance
    
    def register(self, resource_type: str, handler: Callable):
        """Register a resource handler."""
        self._resources[resource_type] = handler
    
    def get_handler(self, resource_type: str) -> Optional[Callable]:
        """Get a handler for the given resource type."""
        return self._resources.get(resource_type)

class MCPRequest(BaseModel):
    """Base MCP request model."""
    action: str
    params: Dict[str, Any] = {}

class MCPResponse(BaseModel):
    """Base MCP response model."""
    success: bool
    data: Dict[str, Any] = {}
    error: Optional[str] = None

def resource(resource_type: str):
    """Decorator to register a function as an MCP resource handler."""
    def decorator(func: F) -> F:
        registry = ResourceRegistry()
        registry.register(resource_type, func)
        
        @wraps(func)
        async def wrapper(*args, **kwargs):
            try:
                result = await func(*args, **kwargs)
                return MCPResponse(success=True, data=result)
            except MCPError as e:
                return MCPResponse(success=False, error=str(e))
            except Exception as e:
                logger.error(f"Error in {resource_type} handler: {str(e)}")
                return MCPResponse(success=False, error="Internal server error")
        return wrapper  # type: ignore
    return decorator

class MCPServer:
    """Base MCP server implementation."""
    
    def __init__(self, name: str, version: str = "1.0.0"):
        self.app = FastAPI(title=name, version=version)
        self.name = name
        self.version = version
        self._setup_routes()
    
    def _setup_routes(self):
        @self.app.post("/mcp/{resource_type}")
        async def handle_request(
            resource_type: str,
            request: MCPRequest,
            registry: ResourceRegistry = Depends(lambda: ResourceRegistry())
        ) -> MCPResponse:
            handler = registry.get_handler(resource_type)
            if not handler:
                raise HTTPException(status_code=404, detail=f"Resource '{resource_type}' not found")
            
            return await handler(**request.params)
        
        @self.app.get("/health")
        async def health_check() -> Dict[str, str]:
            return {"status": "ok", "service": self.name, "version": self.version}
    
    def run(self, host: str = "0.0.0.0", port: int = 8000):
        """Run the MCP server."""
        import uvicorn
        uvicorn.run(self.app, host=host, port=port)
