#!/usr/bin/env python3
"""
DRL Simulator - Community Master Server
Coordinates P2P multiplayer sessions

Features:
- Session registration and discovery
- Player count tracking  
- NAT punch-through assistance (STUN-like)
- WebSocket for real-time session updates
- REST API for session management
- Track availability info for custom tracks

Run:
  python3 master_server.py --port 8080
  
API Endpoints:
  GET  /api/sessions                - List all active sessions
  POST /api/sessions                - Register a new session
  GET  /api/sessions/<id>           - Get session details
  PUT  /api/sessions/<id>           - Update session (player counts, etc)
  DELETE /api/sessions/<id>         - Remove session
  POST /api/sessions/<id>/join      - Request to join (returns host connection info)
  GET  /api/tracks/<track_id>       - Check if track is available
  
WebSocket:
  ws://host:port/ws                 - Real-time session updates
"""

import asyncio
import json
import time
import uuid
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set
from dataclasses import dataclass, field, asdict
from pathlib import Path
import argparse

try:
    from aiohttp import web
    import aiohttp
except ImportError:
    print("Please install aiohttp: pip install aiohttp")
    exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class Player:
    steam_id: str
    name: str
    avatar_url: str = ""
    is_host: bool = False
    is_spectator: bool = False
    joined_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())


@dataclass
class GameSession:
    session_id: str
    host_steam_id: str
    host_name: str
    host_avatar_url: str
    host_ip: str
    host_port: int
    
    room_name: str
    map_id: str
    track_id: str
    is_custom_track: bool
    game_mode: str  # "race", "freestyle", "training"
    
    max_pilots: int = 6
    max_spectators: int = 15
    current_pilots: int = 1  # Host counts as pilot
    current_spectators: int = 0
    
    laps: int = 3
    physics_mode: str = "sim"  # "sim" or "arcade"
    allow_track_download: bool = True
    password_hash: str = ""  # Optional password protection
    
    status: str = "lobby"  # "lobby", "in_race", "finished"
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    last_heartbeat: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    
    players: List[Player] = field(default_factory=list)
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization"""
        d = asdict(self)
        # Don't expose password hash in listings
        d['has_password'] = bool(self.password_hash)
        del d['password_hash']
        return d
    
    def is_full(self) -> bool:
        return self.current_pilots >= self.max_pilots
    
    def is_spectator_full(self) -> bool:
        return self.current_spectators >= self.max_spectators


class SessionManager:
    """Manages all active game sessions"""
    
    def __init__(self, session_timeout: int = 120):
        self.sessions: Dict[str, GameSession] = {}
        self.session_timeout = session_timeout  # Seconds before inactive session expires
        self.websockets: Set[web.WebSocketResponse] = set()
    
    def create_session(self, data: dict) -> GameSession:
        """Create a new game session"""
        session_id = str(uuid.uuid4())[:8]
        
        session = GameSession(
            session_id=session_id,
            host_steam_id=data['host_steam_id'],
            host_name=data.get('host_name', f"Player_{data['host_steam_id'][-6:]}"),
            host_avatar_url=data.get('host_avatar_url', ''),
            host_ip=data.get('host_ip', '0.0.0.0'),
            host_port=data.get('host_port', 5056),
            room_name=data.get('room_name', f"{data.get('host_name', 'Unknown')}'s Room"),
            map_id=data.get('map_id', 'MP-3fd'),
            track_id=data.get('track_id', ''),
            is_custom_track=data.get('is_custom_track', False),
            game_mode=data.get('game_mode', 'race'),
            max_pilots=min(data.get('max_pilots', 6), 6),
            max_spectators=min(data.get('max_spectators', 15), 15),
            laps=data.get('laps', 3),
            physics_mode=data.get('physics_mode', 'sim'),
            allow_track_download=data.get('allow_track_download', True),
        )
        
        # Add password if provided
        if data.get('password'):
            session.password_hash = hashlib.sha256(data['password'].encode()).hexdigest()
        
        # Add host as first player
        host_player = Player(
            steam_id=session.host_steam_id,
            name=session.host_name,
            avatar_url=session.host_avatar_url,
            is_host=True,
            is_spectator=False
        )
        session.players.append(host_player)
        
        self.sessions[session_id] = session
        logger.info(f"Session created: {session_id} by {session.host_name}")
        
        # Notify websocket clients
        asyncio.create_task(self.broadcast_update('session_created', session.to_dict()))
        
        return session
    
    def get_session(self, session_id: str) -> Optional[GameSession]:
        return self.sessions.get(session_id)
    
    def update_session(self, session_id: str, data: dict) -> Optional[GameSession]:
        """Update session with new data"""
        session = self.sessions.get(session_id)
        if not session:
            return None
        
        # Update allowed fields
        updateable = ['status', 'current_pilots', 'current_spectators', 'map_id', 
                     'track_id', 'is_custom_track', 'laps', 'room_name']
        for field in updateable:
            if field in data:
                setattr(session, field, data[field])
        
        session.last_heartbeat = datetime.utcnow().isoformat()
        
        # Notify websocket clients
        asyncio.create_task(self.broadcast_update('session_updated', session.to_dict()))
        
        return session
    
    def heartbeat(self, session_id: str) -> bool:
        """Update session heartbeat to keep it alive"""
        session = self.sessions.get(session_id)
        if session:
            session.last_heartbeat = datetime.utcnow().isoformat()
            return True
        return False
    
    def delete_session(self, session_id: str) -> bool:
        """Remove a session"""
        if session_id in self.sessions:
            session = self.sessions.pop(session_id)
            logger.info(f"Session deleted: {session_id}")
            asyncio.create_task(self.broadcast_update('session_deleted', {'session_id': session_id}))
            return True
        return False
    
    def add_player(self, session_id: str, player_data: dict, as_spectator: bool = False) -> Optional[Player]:
        """Add a player to a session"""
        session = self.sessions.get(session_id)
        if not session:
            return None
        
        # Check capacity
        if as_spectator:
            if session.is_spectator_full():
                return None
            session.current_spectators += 1
        else:
            if session.is_full():
                return None
            session.current_pilots += 1
        
        player = Player(
            steam_id=player_data['steam_id'],
            name=player_data.get('name', f"Player_{player_data['steam_id'][-6:]}"),
            avatar_url=player_data.get('avatar_url', ''),
            is_host=False,
            is_spectator=as_spectator
        )
        session.players.append(player)
        
        # Notify websocket clients
        asyncio.create_task(self.broadcast_update('player_joined', {
            'session_id': session_id,
            'player': asdict(player)
        }))
        
        return player
    
    def remove_player(self, session_id: str, steam_id: str) -> bool:
        """Remove a player from a session"""
        session = self.sessions.get(session_id)
        if not session:
            return False
        
        for i, player in enumerate(session.players):
            if player.steam_id == steam_id:
                removed = session.players.pop(i)
                if removed.is_spectator:
                    session.current_spectators -= 1
                else:
                    session.current_pilots -= 1
                
                # If host left, delete the session
                if removed.is_host:
                    self.delete_session(session_id)
                else:
                    asyncio.create_task(self.broadcast_update('player_left', {
                        'session_id': session_id,
                        'steam_id': steam_id
                    }))
                return True
        return False
    
    def list_sessions(self, game_mode: str = None, has_slots: bool = True) -> List[dict]:
        """List all sessions, optionally filtered"""
        sessions = []
        for session in self.sessions.values():
            # Filter by game mode if specified
            if game_mode and session.game_mode != game_mode:
                continue
            # Filter by available slots
            if has_slots and session.is_full():
                continue
            sessions.append(session.to_dict())
        
        # Sort by creation time (newest first)
        sessions.sort(key=lambda s: s['created_at'], reverse=True)
        return sessions
    
    def cleanup_stale_sessions(self):
        """Remove sessions that haven't had a heartbeat recently"""
        now = datetime.utcnow()
        stale = []
        for session_id, session in self.sessions.items():
            last_heartbeat = datetime.fromisoformat(session.last_heartbeat.replace('Z', ''))
            if (now - last_heartbeat).total_seconds() > self.session_timeout:
                stale.append(session_id)
        
        for session_id in stale:
            logger.info(f"Removing stale session: {session_id}")
            self.delete_session(session_id)
    
    async def broadcast_update(self, event_type: str, data: dict):
        """Send update to all connected WebSocket clients"""
        message = json.dumps({
            'type': event_type,
            'data': data,
            'timestamp': datetime.utcnow().isoformat()
        })
        
        dead_sockets = set()
        for ws in self.websockets:
            try:
                await ws.send_str(message)
            except Exception:
                dead_sockets.add(ws)
        
        # Clean up dead connections
        self.websockets -= dead_sockets


# Global session manager
session_manager = SessionManager()


# HTTP Request Handlers
async def list_sessions(request):
    """GET /api/sessions - List all sessions"""
    game_mode = request.query.get('mode')
    has_slots = request.query.get('available', 'true').lower() == 'true'
    
    sessions = session_manager.list_sessions(game_mode=game_mode, has_slots=has_slots)
    return web.json_response({
        'sessions': sessions,
        'count': len(sessions)
    })


async def create_session(request):
    """POST /api/sessions - Create a new session"""
    try:
        data = await request.json()
    except Exception:
        return web.json_response({'error': 'Invalid JSON'}, status=400)
    
    # Validate required fields
    if 'host_steam_id' not in data:
        return web.json_response({'error': 'host_steam_id is required'}, status=400)
    
    # Get client IP for host
    peername = request.transport.get_extra_info('peername')
    if peername:
        data['host_ip'] = peername[0]
    
    # Check for X-Forwarded-For header (if behind proxy)
    forwarded = request.headers.get('X-Forwarded-For')
    if forwarded:
        data['host_ip'] = forwarded.split(',')[0].strip()
    
    session = session_manager.create_session(data)
    return web.json_response(session.to_dict(), status=201)


async def get_session(request):
    """GET /api/sessions/<id> - Get session details"""
    session_id = request.match_info['id']
    session = session_manager.get_session(session_id)
    
    if not session:
        return web.json_response({'error': 'Session not found'}, status=404)
    
    return web.json_response(session.to_dict())


async def update_session(request):
    """PUT /api/sessions/<id> - Update session"""
    session_id = request.match_info['id']
    
    try:
        data = await request.json()
    except Exception:
        return web.json_response({'error': 'Invalid JSON'}, status=400)
    
    session = session_manager.update_session(session_id, data)
    if not session:
        return web.json_response({'error': 'Session not found'}, status=404)
    
    return web.json_response(session.to_dict())


async def delete_session(request):
    """DELETE /api/sessions/<id> - Delete session"""
    session_id = request.match_info['id']
    
    if session_manager.delete_session(session_id):
        return web.json_response({'status': 'deleted'})
    return web.json_response({'error': 'Session not found'}, status=404)


async def heartbeat_session(request):
    """POST /api/sessions/<id>/heartbeat - Keep session alive"""
    session_id = request.match_info['id']
    
    if session_manager.heartbeat(session_id):
        return web.json_response({'status': 'ok'})
    return web.json_response({'error': 'Session not found'}, status=404)


async def join_session(request):
    """POST /api/sessions/<id>/join - Join a session"""
    session_id = request.match_info['id']
    
    try:
        data = await request.json()
    except Exception:
        return web.json_response({'error': 'Invalid JSON'}, status=400)
    
    session = session_manager.get_session(session_id)
    if not session:
        return web.json_response({'error': 'Session not found'}, status=404)
    
    # Check password if set
    if session.password_hash:
        password = data.get('password', '')
        if hashlib.sha256(password.encode()).hexdigest() != session.password_hash:
            return web.json_response({'error': 'Invalid password'}, status=403)
    
    as_spectator = data.get('as_spectator', False)
    
    # Add player
    player = session_manager.add_player(session_id, data, as_spectator=as_spectator)
    if not player:
        return web.json_response({'error': 'Session is full'}, status=409)
    
    # Return connection info
    return web.json_response({
        'status': 'joined',
        'connection': {
            'host_ip': session.host_ip,
            'host_port': session.host_port,
            'session_id': session_id
        },
        'track': {
            'map_id': session.map_id,
            'track_id': session.track_id,
            'is_custom': session.is_custom_track,
            'download_allowed': session.allow_track_download
        }
    })


async def leave_session(request):
    """POST /api/sessions/<id>/leave - Leave a session"""
    session_id = request.match_info['id']
    
    try:
        data = await request.json()
    except Exception:
        return web.json_response({'error': 'Invalid JSON'}, status=400)
    
    steam_id = data.get('steam_id')
    if not steam_id:
        return web.json_response({'error': 'steam_id is required'}, status=400)
    
    if session_manager.remove_player(session_id, steam_id):
        return web.json_response({'status': 'left'})
    return web.json_response({'error': 'Player not in session'}, status=404)


async def websocket_handler(request):
    """WebSocket endpoint for real-time session updates"""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    session_manager.websockets.add(ws)
    logger.info(f"WebSocket client connected. Total: {len(session_manager.websockets)}")
    
    # Send current session list on connect
    await ws.send_str(json.dumps({
        'type': 'initial',
        'data': {'sessions': session_manager.list_sessions()},
        'timestamp': datetime.utcnow().isoformat()
    }))
    
    try:
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                # Handle client messages (e.g., subscribe to specific session)
                try:
                    data = json.loads(msg.data)
                    if data.get('type') == 'ping':
                        await ws.send_str(json.dumps({'type': 'pong'}))
                except json.JSONDecodeError:
                    pass
            elif msg.type == aiohttp.WSMsgType.ERROR:
                logger.error(f'WebSocket error: {ws.exception()}')
    finally:
        session_manager.websockets.discard(ws)
        logger.info(f"WebSocket client disconnected. Total: {len(session_manager.websockets)}")
    
    return ws


async def health_check(request):
    """GET /health - Health check endpoint"""
    return web.json_response({
        'status': 'healthy',
        'active_sessions': len(session_manager.sessions),
        'connected_clients': len(session_manager.websockets)
    })


async def cleanup_task():
    """Periodic cleanup of stale sessions"""
    while True:
        await asyncio.sleep(30)
        session_manager.cleanup_stale_sessions()


def create_app():
    """Create and configure the web application"""
    app = web.Application()
    
    # Setup routes
    app.router.add_get('/health', health_check)
    app.router.add_get('/api/sessions', list_sessions)
    app.router.add_post('/api/sessions', create_session)
    app.router.add_get('/api/sessions/{id}', get_session)
    app.router.add_put('/api/sessions/{id}', update_session)
    app.router.add_delete('/api/sessions/{id}', delete_session)
    app.router.add_post('/api/sessions/{id}/heartbeat', heartbeat_session)
    app.router.add_post('/api/sessions/{id}/join', join_session)
    app.router.add_post('/api/sessions/{id}/leave', leave_session)
    app.router.add_get('/ws', websocket_handler)
    
    # CORS headers for browser clients
    async def cors_middleware(app, handler):
        async def middleware_handler(request):
            if request.method == 'OPTIONS':
                return web.Response(headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type',
                })
            response = await handler(request)
            response.headers['Access-Control-Allow-Origin'] = '*'
            return response
        return middleware_handler
    
    app.middlewares.append(cors_middleware)
    
    return app


async def main(host: str, port: int):
    """Main entry point"""
    app = create_app()
    
    # Start cleanup task
    asyncio.create_task(cleanup_task())
    
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()
    
    logger.info(f"=" * 60)
    logger.info(f"DRL Community Master Server")
    logger.info(f"=" * 60)
    logger.info(f"HTTP API:   http://{host}:{port}/api/sessions")
    logger.info(f"WebSocket:  ws://{host}:{port}/ws")
    logger.info(f"Health:     http://{host}:{port}/health")
    logger.info(f"=" * 60)
    
    # Keep running
    await asyncio.Event().wait()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='DRL Community Master Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to listen on')
    args = parser.parse_args()
    
    try:
        asyncio.run(main(args.host, args.port))
    except KeyboardInterrupt:
        logger.info("Shutting down...")
