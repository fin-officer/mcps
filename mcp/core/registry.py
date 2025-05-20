"""Resource registry for MCP servers."""

from typing import Dict, Any, Callable, Optional
import functools

class ResourceRegistry:
    """Registry for MCP resources."""
    
    def __init__(self):
        self.handlers = {}
    
    def register(self, resource_type: str, handler: Callable):
        """Register a handler for a resource type."""
        self.handlers[resource_type] = handler
    
    def get_handler(self, resource_type: str) -> Optional[Callable]:
        """Get a handler for a resource type."""
        return self.handlers.get(resource_type)


def resource(resource_type: str):
    """Decorator to register a resource handler."""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            return func(*args, **kwargs)
        
        # Register the handler
        registry = ResourceRegistry()
        registry.register(resource_type, func)
        
        return wrapper
    return decorator
