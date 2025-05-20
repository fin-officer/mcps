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
        @self.app.api_route("/mcp/{resource_path:path}", methods=["POST", "GET", "PUT", "DELETE"])
        async def handle_request(
            request: Request,
            resource_path: str,
            registry: ResourceRegistry = Depends(lambda: ResourceRegistry())
        ) -> MCPResponse:
            try:
                # Parse request body for POST/PUT
                if request.method in ["POST", "PUT"]:
                    body = await request.json()
                    params = body.get("params", {}) if isinstance(body, dict) else {}
                    action = body.get("action", "") if isinstance(body, dict) else ""
                else:
                    params = dict(request.query_params)
                    action = params.pop("action", "")
                
                # Get handler for the resource
                handler = registry.get_handler(resource_path)
                if not handler:
                    raise HTTPException(status_code=404, detail=f"Resource '{resource_path}' not found")
                
                # If no action specified, try to infer from HTTP method
                if not action and request.method != "POST":
                    action = request.method.lower()
                
                # Call the handler with params
                if action:
                    params["action"] = action
                
                result = await handler(**params)
                
                # If result is already an MCPResponse, return it directly
                if isinstance(result, MCPResponse):
                    return result
                    
                # Otherwise wrap in MCPResponse
                return MCPResponse(success=True, data=result)
                
            except HTTPException as he:
                raise he
            except json.JSONDecodeError:
                raise HTTPException(status_code=400, detail="Invalid JSON in request body")
            except Exception as e:
                logger.error(f"Error processing request: {str(e)}", exc_info=True)
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.get("/health")
        async def health_check() -> Dict[str, str]:
            return {"status": "ok", "service": self.name, "version": self.version}
    
    def run(self, host: str = "0.0.0.0", port: int = 8000):
        """Run the MCP server."""
        import uvicorn
        uvicorn.run(self.app, host=host, port=port)
