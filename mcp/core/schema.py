"""Schema definitions for MCP requests and responses."""

from typing import Dict, Any, Optional
from pydantic import BaseModel

class MCPRequest(BaseModel):
    """MCP request schema."""
    id: str
    source: str = ""
    target: str = ""
    type: str = "command"  # "query" | "command"
    action: str
    params: Dict[str, Any] = {}
    context: Optional[Dict[str, Any]] = {}

class MCPResponse(BaseModel):
    """MCP response schema."""
    success: bool = True
    data: Any = None
    error: Optional[str] = None
    context: Optional[Dict[str, Any]] = {}

class MCPError(Exception):
    """MCP error exception."""
    
    def __init__(self, message: str):
        self.message = message
        super().__init__(message)
