"""Example of using the MCP client with the Filesystem server."""
import asyncio
import os
from pathlib import Path
from mcp.client import MCPClient

async def main():
    # Initialize the client (assuming the filesystem server is running on port 8000)
    async with MCPClient("http://localhost:8000") as client:
        # 1. Check server health
        health = await client.health_check()
        print(f"Server health: {health}")
        
        # 2. List files in the current directory
        response = await client.call(
            resource_type="filesystem",
            action="listDirectory",
            params={"path": "."}
        )
        
        if response.success:
            print("\nFiles in current directory:")
            for item in response.data.get("entries", []):
                print(f"- {item['name']} ({'dir' if item['isDirectory'] else 'file'})")
        else:
            print(f"Error: {response.error}")
        
        # 3. Create a test file
        test_file = "test_mcp.txt"
        response = await client.call(
            resource_type="filesystem",
            action="writeFile",
            params={
                "path": test_file,
                "content": "Hello from MCP Client!\nThis is a test file."
            }
        )
        
        if response.success:
            print(f"\nCreated test file: {test_file}")
        else:
            print(f"Error creating file: {response.error}")
        
        # 4. Read the test file
        response = await client.call(
            resource_type="filesystem",
            action="readFile",
            params={"path": test_file}
        )
        
        if response.success:
            print(f"\nFile content:")
            print(response.data.get("content", ""))
        else:
            print(f"Error reading file: {response.error}")
        
        # 5. Clean up (delete the test file)
        response = await client.call(
            resource_type="filesystem",
            action="deleteFile",
            params={"path": test_file}
        )
        
        if response.success:
            print(f"\nDeleted test file: {test_file}")
        else:
            print(f"Error deleting file: {response.error}")

if __name__ == "__main__":
    asyncio.run(main())
