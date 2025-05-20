"""Puppeteer MCP Server for browser automation."""

import os
import json
import asyncio
import logging
from typing import Dict, Any, List, Optional

from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from mcp.core.registry import ResourceRegistry, resource
from mcp.core.schema import MCPResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Puppeteer MCP Server",
    description="MCP Server for browser automation using Puppeteer",
    version="0.1.0",
)

# Puppeteer process pool
class PuppeteerManager:
    def __init__(self):
        self.browsers = {}
        self.pages = {}
        self.next_browser_id = 1
        self.next_page_id = 1
        self.puppeteer_path = os.environ.get("PUPPETEER_PATH", "puppeteer")
    
    async def launch_browser(self, headless: bool = True, args: List[str] = None) -> Dict[str, Any]:
        """Launch a new browser instance."""
        browser_id = str(self.next_browser_id)
        self.next_browser_id += 1
        
        cmd = [
            "node", "-e",
            f"const puppeteer = require('{self.puppeteer_path}'); "
            f"(async () => {{"
            f"  const browser = await puppeteer.launch({{"
            f"    headless: {str(headless).lower()},"
            f"    args: {json.dumps(args or ['--no-sandbox', '--disable-setuid-sandbox'])}"
            f"  }});"
            f"  console.log(JSON.stringify({{"
            f"    wsEndpoint: browser.wsEndpoint(),"
            f"    version: await browser.version()"
            f"  }}));"
            f"  process.stdin.on('data', data => {{"
            f"    if (data.toString().trim() === 'close') {{"
            f"      browser.close().then(() => process.exit(0));"
            f"    }}"
            f"  }});"
            f"}})();"
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        if process.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to launch browser: {stderr.decode()}")
        
        try:
            browser_info = json.loads(stdout.decode().strip())
            browser_info["id"] = browser_id
            self.browsers[browser_id] = {
                "process": process,
                "wsEndpoint": browser_info["wsEndpoint"],
                "version": browser_info["version"]
            }
            return browser_info
        except json.JSONDecodeError:
            raise HTTPException(status_code=500, detail=f"Invalid response from browser: {stdout.decode()}")
    
    async def close_browser(self, browser_id: str) -> Dict[str, Any]:
        """Close a browser instance."""
        if browser_id not in self.browsers:
            raise HTTPException(status_code=404, detail=f"Browser {browser_id} not found")
        
        browser = self.browsers[browser_id]
        process = browser["process"]
        
        try:
            process.stdin.write(b"close\n")
            await process.stdin.drain()
            await process.wait()
            del self.browsers[browser_id]
            return {"success": True, "message": f"Browser {browser_id} closed"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to close browser: {str(e)}")
    
    async def new_page(self, browser_id: str) -> Dict[str, Any]:
        """Create a new page in a browser."""
        if browser_id not in self.browsers:
            raise HTTPException(status_code=404, detail=f"Browser {browser_id} not found")
        
        page_id = str(self.next_page_id)
        self.next_page_id += 1
        
        ws_endpoint = self.browsers[browser_id]["wsEndpoint"]
        
        cmd = [
            "node", "-e",
            f"const puppeteer = require('{self.puppeteer_path}'); "
            f"(async () => {{"
            f"  const browser = await puppeteer.connect({{"
            f"    browserWSEndpoint: '{ws_endpoint}'"
            f"  }});"
            f"  const page = await browser.newPage();"
            f"  await page.setViewport({{ width: 1280, height: 800 }});"
            f"  console.log(JSON.stringify({{"
            f"    url: page.url(),"
            f"    title: await page.title()"
            f"  }}));"
            f"  process.stdin.on('data', async data => {{"
            f"    const cmd = data.toString().trim();"
            f"    if (cmd === 'close') {{"
            f"      await page.close();"
            f"      process.exit(0);"
            f"    }} else {{"
            f"      try {{"
            f"        const result = await eval(`(async () => ${{cmd}})()`);"
            f"        console.log(JSON.stringify({{ result }}));"
            f"      }} catch (e) {{"
            f"        console.error(JSON.stringify({{ error: e.toString() }}));"
            f"      }}"
            f"    }}"
            f"  }});"
            f"}})();"
        ]
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stdin=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate(None, 5.0)  # 5 second timeout
        if process.returncode is not None and process.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to create page: {stderr.decode()}")
        
        try:
            page_info = json.loads(stdout.decode().strip())
            page_info["id"] = page_id
            self.pages[page_id] = {
                "process": process,
                "browser_id": browser_id
            }
            return page_info
        except json.JSONDecodeError:
            raise HTTPException(status_code=500, detail=f"Invalid response from page: {stdout.decode()}")
    
    async def close_page(self, page_id: str) -> Dict[str, Any]:
        """Close a page."""
        if page_id not in self.pages:
            raise HTTPException(status_code=404, detail=f"Page {page_id} not found")
        
        page = self.pages[page_id]
        process = page["process"]
        
        try:
            process.stdin.write(b"close\n")
            await process.stdin.drain()
            await process.wait()
            del self.pages[page_id]
            return {"success": True, "message": f"Page {page_id} closed"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to close page: {str(e)}")
    
    async def execute_on_page(self, page_id: str, command: str) -> Dict[str, Any]:
        """Execute a command on a page."""
        if page_id not in self.pages:
            raise HTTPException(status_code=404, detail=f"Page {page_id} not found")
        
        page = self.pages[page_id]
        process = page["process"]
        
        try:
            process.stdin.write(f"{command}\n".encode())
            await process.stdin.drain()
            
            # Read the response
            stdout_data = await process.stdout.readline()
            if not stdout_data:
                stderr_data = await process.stderr.readline()
                raise HTTPException(status_code=500, detail=f"Failed to execute command: {stderr_data.decode()}")
            
            try:
                result = json.loads(stdout_data.decode().strip())
                if "error" in result:
                    raise HTTPException(status_code=500, detail=f"Command execution error: {result['error']}")
                return result
            except json.JSONDecodeError:
                raise HTTPException(status_code=500, detail=f"Invalid response from page: {stdout_data.decode()}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to execute command: {str(e)}")

# Singleton instance of PuppeteerManager
puppeteer_manager = PuppeteerManager()

# Resource registry
registry = ResourceRegistry()

# Models
class LaunchBrowserRequest(BaseModel):
    headless: bool = True
    args: Optional[List[str]] = None

class BrowserIdRequest(BaseModel):
    browser_id: str

class PageIdRequest(BaseModel):
    page_id: str

class NavigateRequest(BaseModel):
    page_id: str
    url: str
    wait_until: str = "networkidle0"  # networkidle0, networkidle2, domcontentloaded, load

class ScreenshotRequest(BaseModel):
    page_id: str
    path: Optional[str] = None
    full_page: bool = False
    type: str = "png"  # png, jpeg
    quality: Optional[int] = None  # 0-100, only for jpeg
    encoding: str = "base64"  # base64, binary

class EvaluateRequest(BaseModel):
    page_id: str
    expression: str

class ClickRequest(BaseModel):
    page_id: str
    selector: str

class TypeRequest(BaseModel):
    page_id: str
    selector: str
    text: str
    delay: int = 0

class WaitForSelectorRequest(BaseModel):
    page_id: str
    selector: str
    timeout: int = 30000
    visible: bool = False
    hidden: bool = False

# Resource handlers
@resource("puppeteer.browser.launch")
async def launch_browser(headless: bool = True, args: Optional[List[str]] = None) -> Dict[str, Any]:
    """Launch a new browser instance."""
    return await puppeteer_manager.launch_browser(headless, args)

@resource("puppeteer.browser.close")
async def close_browser(browser_id: str) -> Dict[str, Any]:
    """Close a browser instance."""
    return await puppeteer_manager.close_browser(browser_id)

@resource("puppeteer.page.new")
async def new_page(browser_id: str) -> Dict[str, Any]:
    """Create a new page in a browser."""
    return await puppeteer_manager.new_page(browser_id)

@resource("puppeteer.page.close")
async def close_page(page_id: str) -> Dict[str, Any]:
    """Close a page."""
    return await puppeteer_manager.close_page(page_id)

@resource("puppeteer.page.navigate")
async def navigate(page_id: str, url: str, wait_until: str = "networkidle0") -> Dict[str, Any]:
    """Navigate to a URL."""
    command = f"page.goto('{url}', {{ waitUntil: '{wait_until}' }}); return {{ url: page.url(), title: await page.title() }};"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.screenshot")
async def screenshot(page_id: str, path: Optional[str] = None, full_page: bool = False, 
                    type: str = "png", quality: Optional[int] = None, encoding: str = "base64") -> Dict[str, Any]:
    """Take a screenshot of a page."""
    options = {
        "fullPage": full_page,
        "type": type,
        "encoding": encoding
    }
    
    if path:
        options["path"] = path
    
    if quality and type == "jpeg":
        options["quality"] = quality
    
    options_str = json.dumps(options)
    command = f"page.screenshot({options_str})"
    result = await puppeteer_manager.execute_on_page(page_id, command)
    
    return result

@resource("puppeteer.page.evaluate")
async def evaluate(page_id: str, expression: str) -> Dict[str, Any]:
    """Evaluate an expression on a page."""
    command = f"page.evaluate(() => {{ {expression} }})"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.click")
async def click(page_id: str, selector: str) -> Dict[str, Any]:
    """Click on an element."""
    command = f"page.click('{selector}')"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.type")
async def type_text(page_id: str, selector: str, text: str, delay: int = 0) -> Dict[str, Any]:
    """Type text into an element."""
    command = f"page.type('{selector}', '{text}', {{ delay: {delay} }})"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.waitForSelector")
async def wait_for_selector(page_id: str, selector: str, timeout: int = 30000, 
                           visible: bool = False, hidden: bool = False) -> Dict[str, Any]:
    """Wait for an element matching the selector."""
    options = {
        "timeout": timeout,
        "visible": visible,
        "hidden": hidden
    }
    
    options_str = json.dumps(options)
    command = f"page.waitForSelector('{selector}', {options_str})"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.content")
async def get_content(page_id: str) -> Dict[str, Any]:
    """Get the HTML content of a page."""
    command = "page.content()"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.title")
async def get_title(page_id: str) -> Dict[str, Any]:
    """Get the title of a page."""
    command = "page.title()"
    return await puppeteer_manager.execute_on_page(page_id, command)

@resource("puppeteer.page.url")
async def get_url(page_id: str) -> Dict[str, Any]:
    """Get the URL of a page."""
    command = "page.url()"
    return await puppeteer_manager.execute_on_page(page_id, command)

# Register resources
for resource_name, handler in registry.handlers.items():
    logger.info(f"Registered resource: {resource_name}")

# Health check endpoint
@app.get("/health")
async def health_check() -> Dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
