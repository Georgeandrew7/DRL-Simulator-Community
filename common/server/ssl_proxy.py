#!/usr/bin/env python3
"""
DRL SSL Termination Proxy

This script acts as a transparent SSL termination proxy.
The game connects to us via HTTP on localhost, and we forward to the mock server via HTTPS.

Flow:
  Game -> HTTP on port 8443 (this proxy) -> HTTP to mock server on port 80

This avoids the SSL certificate validation issue entirely by having the game
use HTTP instead of HTTPS.
"""

import http.server
import socketserver
import urllib.request
import ssl
import json
import sys
import socket

# Configuration
PROXY_PORT = 8443  # Port this proxy listens on (HTTP)
BACKEND_HOST = "127.0.0.1"
BACKEND_PORT = 80  # Mock server HTTP port

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    """HTTP proxy that forwards requests to the mock backend."""
    
    def log_message(self, format, *args):
        """Custom logging."""
        print(f"[PROXY] {args[0]}")
    
    def do_GET(self):
        self.proxy_request("GET")
    
    def do_POST(self):
        self.proxy_request("POST")
    
    def do_PUT(self):
        self.proxy_request("PUT")
    
    def do_DELETE(self):
        self.proxy_request("DELETE")
    
    def proxy_request(self, method):
        """Forward request to backend."""
        try:
            # Build backend URL
            backend_url = f"http://{BACKEND_HOST}:{BACKEND_PORT}{self.path}"
            print(f"[PROXY] {method} {self.path} -> {backend_url}")
            
            # Read request body if present
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Create request
            req = urllib.request.Request(backend_url, data=body, method=method)
            
            # Copy headers (except Host)
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'content-length']:
                    req.add_header(header, value)
            
            # Make request to backend
            try:
                with urllib.request.urlopen(req, timeout=10) as response:
                    # Send response status
                    self.send_response(response.status)
                    
                    # Send response headers
                    for header, value in response.getheaders():
                        if header.lower() not in ['transfer-encoding', 'connection']:
                            self.send_header(header, value)
                    self.end_headers()
                    
                    # Send response body
                    self.wfile.write(response.read())
                    
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(e.read())
                
        except Exception as e:
            print(f"[PROXY] Error: {e}")
            self.send_error(502, f"Proxy Error: {e}")


def main():
    """Start the proxy server."""
    print("=" * 60)
    print("DRL SSL Termination Proxy")
    print("=" * 60)
    print()
    print(f"Listening on: http://127.0.0.1:{PROXY_PORT}")
    print(f"Forwarding to: http://{BACKEND_HOST}:{BACKEND_PORT}")
    print()
    print("To use this proxy, modify /etc/hosts:")
    print("  127.0.0.1 api.drlgame.com")
    print()
    print("And the game should connect via HTTP instead of HTTPS.")
    print("(This requires the game to use HTTP, not HTTPS)")
    print()
    print("Press Ctrl+C to stop")
    print()
    
    # Allow address reuse
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PROXY_PORT), ProxyHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nProxy stopped.")


if __name__ == "__main__":
    main()
