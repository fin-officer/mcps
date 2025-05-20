# Puppeteer MCP Server

This MCP server provides browser automation capabilities using Puppeteer, allowing you to control headless Chrome or Chromium browsers for web scraping, testing, and other browser-based tasks.

## Features

- Launch and control Chrome/Chromium browsers
- Create and manage browser pages
- Navigate to URLs
- Take screenshots
- Execute JavaScript in the page context
- Interact with page elements (click, type, etc.)
- Extract page content, title, and URL
- Wait for elements to appear or disappear

## Prerequisites

- Node.js 14+ installed
- Puppeteer npm package (`npm install puppeteer`)
- Python 3.8+ with FastAPI and Uvicorn

## Configuration

The following environment variables can be set in the `.env` file:

```ini
# Puppeteer MCP Server Configuration
PUPPETEER_ENABLED=true
PUPPETEER_PORT=8007
PUPPETEER_PATH=puppeteer
PUPPETEER_HEADLESS=true
```

## API Resources

### Browser Management

#### `puppeteer.browser.launch`

Launch a new browser instance.

**Parameters:**
- `headless` (boolean, optional): Whether to run the browser in headless mode. Default: `true`
- `args` (array of strings, optional): Additional browser arguments. Default: `['--no-sandbox', '--disable-setuid-sandbox']`

**Returns:**
- `id`: Browser ID
- `wsEndpoint`: WebSocket endpoint for connecting to the browser
- `version`: Browser version

**Example:**
```json
{
  "id": "1",
  "wsEndpoint": "ws://127.0.0.1:39123/devtools/browser/1a2b3c4d",
  "version": "Chrome/90.0.4430.212"
}
```

#### `puppeteer.browser.close`

Close a browser instance.

**Parameters:**
- `browser_id` (string): Browser ID to close

**Returns:**
- `success`: Whether the operation was successful
- `message`: Status message

### Page Management

#### `puppeteer.page.new`

Create a new page in a browser.

**Parameters:**
- `browser_id` (string): Browser ID to create the page in

**Returns:**
- `id`: Page ID
- `url`: Initial page URL
- `title`: Initial page title

#### `puppeteer.page.close`

Close a page.

**Parameters:**
- `page_id` (string): Page ID to close

**Returns:**
- `success`: Whether the operation was successful
- `message`: Status message

#### `puppeteer.page.navigate`

Navigate to a URL.

**Parameters:**
- `page_id` (string): Page ID
- `url` (string): URL to navigate to
- `wait_until` (string, optional): When to consider navigation complete. Options: `networkidle0`, `networkidle2`, `domcontentloaded`, `load`. Default: `networkidle0`

**Returns:**
- `url`: Final URL after navigation (may differ from requested URL due to redirects)
- `title`: Page title after navigation

#### `puppeteer.page.screenshot`

Take a screenshot of a page.

**Parameters:**
- `page_id` (string): Page ID
- `path` (string, optional): Path to save the screenshot to
- `full_page` (boolean, optional): Whether to take a screenshot of the full scrollable page. Default: `false`
- `type` (string, optional): Image format. Options: `png`, `jpeg`. Default: `png`
- `quality` (integer, optional): Image quality (0-100), only for JPEG. Default: `null`
- `encoding` (string, optional): Output encoding. Options: `base64`, `binary`. Default: `base64`

**Returns:**
- `result`: Screenshot data (base64-encoded string or binary data)

#### `puppeteer.page.evaluate`

Evaluate JavaScript code in the context of the page.

**Parameters:**
- `page_id` (string): Page ID
- `expression` (string): JavaScript code to evaluate

**Returns:**
- `result`: Result of the evaluation

#### `puppeteer.page.click`

Click on an element.

**Parameters:**
- `page_id` (string): Page ID
- `selector` (string): CSS selector of the element to click

**Returns:**
- `result`: Result of the operation

#### `puppeteer.page.type`

Type text into an element.

**Parameters:**
- `page_id` (string): Page ID
- `selector` (string): CSS selector of the element to type into
- `text` (string): Text to type
- `delay` (integer, optional): Delay between keystrokes in milliseconds. Default: `0`

**Returns:**
- `result`: Result of the operation

#### `puppeteer.page.waitForSelector`

Wait for an element matching the selector to appear or disappear.

**Parameters:**
- `page_id` (string): Page ID
- `selector` (string): CSS selector to wait for
- `timeout` (integer, optional): Maximum time to wait in milliseconds. Default: `30000`
- `visible` (boolean, optional): Wait for element to be visible. Default: `false`
- `hidden` (boolean, optional): Wait for element to be hidden. Default: `false`

**Returns:**
- `result`: Result of the operation

#### `puppeteer.page.content`

Get the HTML content of a page.

**Parameters:**
- `page_id` (string): Page ID

**Returns:**
- `result`: HTML content of the page

#### `puppeteer.page.title`

Get the title of a page.

**Parameters:**
- `page_id` (string): Page ID

**Returns:**
- `result`: Page title

#### `puppeteer.page.url`

Get the URL of a page.

**Parameters:**
- `page_id` (string): Page ID

**Returns:**
- `result`: Page URL

## Example Usage

### Web Scraping Example

```bash
# Launch a browser
curl -X POST http://localhost:8007/mcp/puppeteer.browser.launch \
  -H "Content-Type: application/json" \
  -d '{"headless": true}'

# Create a new page
curl -X POST http://localhost:8007/mcp/puppeteer.page.new \
  -H "Content-Type: application/json" \
  -d '{"browser_id": "1"}'

# Navigate to a URL
curl -X POST http://localhost:8007/mcp/puppeteer.page.navigate \
  -H "Content-Type: application/json" \
  -d '{"page_id": "1", "url": "https://example.com"}'

# Get page content
curl -X POST http://localhost:8007/mcp/puppeteer.page.content \
  -H "Content-Type: application/json" \
  -d '{"page_id": "1"}'

# Take a screenshot
curl -X POST http://localhost:8007/mcp/puppeteer.page.screenshot \
  -H "Content-Type: application/json" \
  -d '{"page_id": "1", "full_page": true}'

# Close the page
curl -X POST http://localhost:8007/mcp/puppeteer.page.close \
  -H "Content-Type: application/json" \
  -d '{"page_id": "1"}'

# Close the browser
curl -X POST http://localhost:8007/mcp/puppeteer.browser.close \
  -H "Content-Type: application/json" \
  -d '{"browser_id": "1"}'
```

## Troubleshooting

### Common Issues

1. **Error: Failed to launch browser**
   - Make sure Node.js is installed and in your PATH
   - Install Puppeteer: `npm install puppeteer`
   - Try running with `--no-sandbox` argument

2. **Error: Page not found**
   - Check if the page ID is correct
   - The page might have been closed already

3. **Error: Browser not found**
   - Check if the browser ID is correct
   - The browser might have been closed already

4. **Error: Timeout exceeded**
   - Increase the timeout value for operations like navigation or waiting for selectors
   - Check your internet connection
   - The page might be loading slowly

## License

MIT
