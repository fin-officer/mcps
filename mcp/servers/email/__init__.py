"""Email MCP Server implementation."""
from typing import Dict, Any, List, Optional
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import ssl

from mcp import resource, MCPError, MCPServer

class EmailMCP:
    """Email MCP server implementation."""
    
    def __init__(self, smtp_server: str, smtp_port: int, username: str, password: str):
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
        self.context = ssl.create_default_context()
    
    @resource("email.send")
    async def send_email(
        self,
        to_email: str,
        subject: str,
        body: str,
        from_email: str = None,
        cc: List[str] = None,
        bcc: List[str] = None,
        is_html: bool = False
    ) -> Dict[str, Any]:
        """Send an email."""
        try:
            from_email = from_email or self.username
            message = MIMEMultipart()
            message['From'] = from_email
            message['To'] = to_email
            message['Subject'] = subject
            
            if cc:
                message['Cc'] = ', '.join(cc)
            if bcc:
                message['Bcc'] = ', '.join(bcc)
            
            # Attach the email body
            content_type = 'html' if is_html else 'plain'
            message.attach(MIMEText(body, content_type))
            
            # Connect to the SMTP server and send the email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls(context=self.context)
                server.login(self.username, self.password)
                recipients = [to_email]
                if cc:
                    recipients.extend(cc)
                if bcc:
                    recipients.extend(bcc)
                server.send_message(message, from_addr=from_email, to_addrs=recipients)
            
            return {"status": "sent", "to": to_email, "subject": subject}
            
        except Exception as e:
            raise MCPError(f"Failed to send email: {str(e)}")
    
    @resource("email.verify")
    async def verify_connection(self) -> Dict[str, Any]:
        """Verify the email server connection."""
        try:
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls(context=self.context)
                server.login(self.username, self.password)
                server.noop()
            return {"status": "connected", "server": self.smtp_server}
        except Exception as e:
            raise MCPError(f"Failed to verify connection: {str(e)}")

def create_email_mcp_server(smtp_server: str, smtp_port: int, username: str, password: str) -> MCPServer:
    """Create and configure an Email MCP server."""
    server = MCPServer("Email MCP Server", "1.0.0")
    email_mcp = EmailMCP(smtp_server, smtp_port, username, password)
    return server
