#!/usr/bin/env python3
"""
DRL Simulator Mock Backend Server

This server mocks the DRL backend API (api.drlgame.com) to allow the game
to function offline after the official servers were shut down.

Services mocked:
- drl.service.time - Returns current server time
- drl.service.login.v2 - Returns a mock successful login
- drl.service.storage.* - Returns empty/success responses
- drl.service.content.manifest - Returns available maps list

Usage:
1. Run this server: sudo python mock_drl_backend.py --https
2. Add to /etc/hosts: 127.0.0.1 api.drlgame.com
3. Launch the game
"""

import json
import time
import os
import subprocess
import base64
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone
import ssl
import argparse
import threading

# Game directory paths - Auto-detect based on platform
def find_game_directory():
    """Find DRL Simulator installation directory"""
    import platform
    
    # Check environment variable first
    env_dir = os.environ.get('DRL_GAME_DIR')
    if env_dir and os.path.exists(env_dir):
        return env_dir
    
    # Common paths to check
    if platform.system() == 'Windows':
        possible_paths = [
            os.path.expandvars(r"%ProgramFiles(x86)%\Steam\steamapps\common\DRL Simulator"),
            os.path.expandvars(r"%ProgramFiles%\Steam\steamapps\common\DRL Simulator"),
            r"C:\Steam\steamapps\common\DRL Simulator",
            r"D:\Steam\steamapps\common\DRL Simulator",
            r"D:\SteamLibrary\steamapps\common\DRL Simulator",
            r"E:\SteamLibrary\steamapps\common\DRL Simulator",
            r"D:\Games\Steam\steamapps\common\DRL Simulator",
            r"D:\Games\SteamLibrary\steamapps\common\DRL Simulator",
        ]
    elif platform.system() == 'Darwin':  # macOS
        possible_paths = [
            os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/DRL Simulator"),
        ]
    else:  # Linux
        possible_paths = [
            os.path.expanduser("~/.local/share/Steam/steamapps/common/DRL Simulator"),
            os.path.expanduser("~/.steam/steam/steamapps/common/DRL Simulator"),
        ]
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    # Return default (may not exist)
    if platform.system() == 'Windows':
        return r"C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator"
    else:
        return os.path.expanduser("~/.local/share/Steam/steamapps/common/DRL Simulator")

GAME_DIR = find_game_directory()
print(f"Game directory: {GAME_DIR}")
print(f"  Exists: {os.path.exists(GAME_DIR)}")

MAPS_DIR = os.path.join(GAME_DIR, "DRL Simulator_Data", "StreamingAssets", "game", "content", "maps")
PLAYER_STATE_PATH = os.path.join(GAME_DIR, "DRL Simulator_Data", "StreamingAssets", "game", "storage", "offline", "state", "player", "player-state.json")

def load_all_tracks():
    """Load all track definitions from local map JSON files - metadata only, no root objects"""
    all_tracks = []
    
    if not os.path.exists(MAPS_DIR):
        return all_tracks
        
    for map_dir in os.listdir(MAPS_DIR):
        map_path = os.path.join(MAPS_DIR, map_dir)
        if not os.path.isdir(map_path):
            continue
            
        for f in os.listdir(map_path):
            if f.endswith('.json'):
                json_path = os.path.join(map_path, f)
                try:
                    with open(json_path, 'r') as fp:
                        data = json.load(fp)
                    if 'data' in data and isinstance(data['data'], dict) and 'data' in data['data']:
                        tracks = data['data']['data']
                        for track in tracks:
                            if isinstance(track, dict) and 'guid' in track:
                                # Extract only metadata, not the huge 'root' scene object
                                track_meta = {
                                    'guid': track.get('guid', ''),
                                    'map-id': track.get('map-id', ''),
                                    'map-title': track.get('map-title', ''),
                                    'map-thumb': track.get('map-thumb', ''),
                                    'map-category': track.get('map-category', 'MapDRL'),
                                    'map-difficulty': track.get('map-difficulty', 1),
                                    'map-distance': track.get('map-distance', 0),
                                    'map-laps': track.get('map-laps', 1),
                                    'track-id': track.get('track-id', 'race'),
                                    'is-public': track.get('is-public', True),
                                    'is-race-allowed': track.get('is-race-allowed', True),
                                    'is-drl-official': track.get('is-drl-official', False),
                                    'is-featured': track.get('is-featured', False),
                                    'steam-id': track.get('steam-id', ''),
                                    'profile-name': track.get('profile-name', ''),
                                    'profile-color': track.get('profile-color', 'ffffff'),
                                    'profile-thumb': track.get('profile-thumb', ''),
                                    'rating-count': track.get('rating-count', 0),
                                    'score': track.get('score', 0),
                                    'created-at': track.get('created-at', ''),
                                    'updated-at': track.get('updated-at', ''),
                                }
                                all_tracks.append(track_meta)
                except:
                    pass
    return all_tracks

def load_full_tracks_by_guid():
    """Load full track data (including root scene) indexed by GUID"""
    tracks_by_guid = {}
    
    if not os.path.exists(MAPS_DIR):
        return tracks_by_guid
        
    for map_dir in os.listdir(MAPS_DIR):
        map_path = os.path.join(MAPS_DIR, map_dir)
        if not os.path.isdir(map_path):
            continue
            
        for f in os.listdir(map_path):
            if f.endswith('.json'):
                json_path = os.path.join(map_path, f)
                try:
                    with open(json_path, 'r') as fp:
                        data = json.load(fp)
                    if 'data' in data and isinstance(data['data'], dict) and 'data' in data['data']:
                        tracks = data['data']['data']
                        for track in tracks:
                            if isinstance(track, dict) and 'guid' in track:
                                guid = track.get('guid')
                                tracks_by_guid[guid] = track  # Full track with root object
                except:
                    pass
    return tracks_by_guid

# Load tracks at startup
ALL_TRACKS = load_all_tracks()
FULL_TRACKS_BY_GUID = load_full_tracks_by_guid()
print(f"Loaded {len(ALL_TRACKS)} tracks from local map files")

# All maps available in the game (from StreamingAssets/game/content/maps)
ALL_MAPS = [
    {"id": "map-adventuredome", "name": "Adventuredome", "enabled": True},
    {"id": "map-airplane-graveyard", "name": "Airplane Graveyard", "enabled": True},
    {"id": "map-allianz-riviera", "name": "Allianz Riviera", "enabled": True},
    {"id": "map-atlanta-aftermath", "name": "Atlanta Aftermath", "enabled": True},
    {"id": "map-bell-labs", "name": "Project Manhattan", "enabled": True},
    {"id": "map-biosphere", "name": "Biosphere 2", "enabled": True},
    {"id": "map-bmw-welt", "name": "BMW Welt", "enabled": True},
    {"id": "map-boston-foundry", "name": "Boston", "enabled": True},
    {"id": "map-bridge", "name": "Bridge", "enabled": True},
    {"id": "map-california-nights", "name": "California Nights", "enabled": True},
    {"id": "map-campground", "name": "Campground", "enabled": True},
    {"id": "map-championship-kingdom", "name": "Championship Kingdom", "enabled": True},
    {"id": "map-detroit", "name": "Detroit", "enabled": True},
    {"id": "map-drone-park", "name": "Drone Park", "enabled": True},
    {"id": "map-field", "name": "Field", "enabled": True},
    {"id": "map-gates-of-hell", "name": "Gates of New York", "enabled": True},
    {"id": "map-house", "name": "House", "enabled": True},
    {"id": "map-lapocalypse", "name": "L.A.pocalypse", "enabled": True},
    {"id": "map-loandepot", "name": "LoanDepot Park", "enabled": True},
    {"id": "map-london", "name": "2017 World Championship", "enabled": True},
    {"id": "map-mardi-gras", "name": "Mardi Gras", "enabled": True},
    {"id": "map-mega-city", "name": "Mega City", "enabled": True},
    {"id": "map-miami-lights", "name": "Miami Lights", "enabled": True},
    {"id": "map-miami-nights", "name": "Hard Rock Stadium", "enabled": True},
    {"id": "map-munich-playoffs", "name": "Munich", "enabled": True},
    {"id": "map-ohio-crash-site", "name": "Ohio", "enabled": True},
    {"id": "map-physics-room", "name": "Physics Room", "enabled": True},
    {"id": "map-sandbox", "name": "Sandbox", "enabled": True},
    {"id": "map-silicon-valley", "name": "Silicon Valley", "enabled": True},
    {"id": "map-skatepark-la", "name": "Skatepark LA", "enabled": True},
    {"id": "map-usaf", "name": "USAF Academy", "enabled": True},
]

class DRLMockHandler(BaseHTTPRequestHandler):
    
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")
    
    def send_json_response(self, data, status=200):
        """Send a JSON response"""
        response = json.dumps(data)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(response.encode())
    
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        path = self.path.split('?')[0]  # Remove query params
        
        print(f"  GET: {self.path}")
        
        # Time service
        if 'time' in path or 'service.time' in self.path:
            self.handle_time()
        
        # Player license
        elif '/player/license' in path:
            self.handle_player_license()
        
        # State endpoints
        elif '/state/game' in path:
            self.handle_game_state()
        elif '/state/' in path or path == '/state':
            self.handle_state()
        
        # Experience/progression endpoints
        elif '/experience-points/' in path or '/progression/' in path:
            self.handle_progression()
        
        # Maps endpoints
        elif '/maps/updated' in path or '/maps/user/updated' in path:
            self.handle_maps_updated()
        
        # Circuits
        elif '/circuits' in path:
            self.handle_circuits()
        
        # Tournaments - return empty array
        elif '/tournaments' in path:
            self.handle_tournaments()
        
        # Content manifest - returns available maps and content
        elif 'manifest' in path or 'content.manifest' in self.path:
            self.handle_content_manifest()
        
        # Maps/content endpoints
        elif '/maps/' in path or '/content/' in path:
            self.handle_content()
        
        # Player endpoints
        elif 'player' in path or 'profile' in path:
            self.handle_player()
        
        # Storage endpoints (GET)
        elif 'storage' in path:
            self.handle_storage()
        
        # Default - return generic success
        else:
            self.handle_generic()
    
    def handle_player_license(self):
        """Handle player license check - return full license
        
        The game DOES use Base64 decoding (FromBase64) on this endpoint.
        The error was ArgumentNullException because we sent raw JSON instead of Base64 string.
        """
        # License data that will be Base64 encoded
        inner_data = {
            "license": True,
            "hasLicense": True,
            "isPremium": True,
            "premium": True,
            "valid": True,
            "active": True,
            "type": "premium",
            "licenseType": "full",
            "expiresAt": None,
            "features": ["multiplayer", "mapEditor", "customTracks", "allMaps"]
        }
        # Must be Base64 encoded string!
        encoded_data = base64.b64encode(json.dumps(inner_data).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data  # Base64 encoded string
        }
        self.send_json_response(data)
    
    def handle_game_state(self):
        """Handle game state request - raw JSON, no Base64"""
        # The game expects specific fields - keep it simple
        inner_data = {
            "version": "4.2.ee16.rls-win",
            "maintenanceMode": False,
            "serverStatus": "online"
            # Don't include features - it may expect a different format
        }
        data = {
            "success": True,
            "message": None,
            "encoded": False,
            "data": inner_data  # Raw JSON, not Base64
        }
        self.send_json_response(data)
    
    def handle_state(self):
        """Handle general state request - return player state from file (Base64 encoded)"""
        try:
            with open(PLAYER_STATE_PATH, 'r') as f:
                player_data = json.load(f)
        except Exception as e:
            print(f"    Could not read player state: {e}")
            player_data = {}
        
        encoded_data = base64.b64encode(json.dumps(player_data).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def handle_state_post(self):
        """Handle POST to /state/ - returns player state (same as GET, POST is used for both read/write)"""
        try:
            with open(PLAYER_STATE_PATH, 'r') as f:
                player_data = json.load(f)
            print(f"    Loaded player state with {len(player_data)} keys")
        except Exception as e:
            print(f"    Could not read player state: {e}")
            player_data = {}
        
        encoded_data = base64.b64encode(json.dumps(player_data).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def handle_progression(self):
        """Handle XP and progression requests"""
        path = self.path.lower()
        if 'maps' in path or 'tracks' in path:
            # progression/maps (drl.service.progression.tracks) expects DRLProgressionTrackData[]
            # The game expects a JSON ARRAY directly in the data field, NOT a wrapped object
            tracks = ALL_TRACKS
            print(f"    Returning {len(tracks)} tracks for progression (plain array)")
            data = {
                "success": True,
                "message": None,
                "encoded": False,
                "data": tracks  # Plain array, NOT wrapped in {pagging, data}
            }
        else:
            # progression/player (drl.service.progression.player) expects raw JSON, NOT Base64
            inner_data = {
                "level": 50,
                "xp": 999999,
                "totalXp": 999999,
                "nextLevelXp": 1000000,
                "rank": 1,
                "mapsCompleted": 100,
                "racesWon": 100,
                "totalRaces": 500,
                "flightTime": 50987
            }
            data = {
                "success": True,
                "message": None,
                "encoded": False,
                "data": inner_data  # Raw JSON, not Base64
            }
        self.send_json_response(data)
    
    def handle_maps_updated(self):
        """Handle maps update check - return empty array (no updates needed)"""
        # Return empty array to indicate no map updates - NOT Base64 encoded
        data = {
            "success": True,
            "message": None,
            "encoded": False,
            "data": []  # Empty array = no updates needed
        }
        self.send_json_response(data)
    
    def handle_circuits(self):
        """Handle circuits/tracks request - return all tracks from local map files
        
        Note: The game primarily reads circuits from circuits-data in the player profile.
        This endpoint may be used to update/refresh circuit data.
        """
        # Use the globally loaded tracks from map JSON files
        tracks = ALL_TRACKS
        print(f"    Returning {len(tracks)} tracks/circuits (plain array)")
        if tracks:
            sample = tracks[0]
            print(f"    Sample track: guid={sample.get('guid')}, title={sample.get('map-title')}")
        
        # Plain array format (same as progression/maps)
        data = {
            "success": True,
            "message": None,
            "encoded": False,
            "data": tracks  # Plain array of track metadata
        }
        self.send_json_response(data)
    
    def handle_tournaments(self):
        """Handle tournaments request - return empty array (no active tournaments)"""
        # Game expects a plain JSON array of tournaments
        data = {
            "success": True,
            "message": None,
            "encoded": False,
            "data": []  # Empty array = no tournaments
        }
        self.send_json_response(data)
    
    def handle_player(self):
        """Handle player/profile data requests - Base64 encoded ARRAY"""
        try:
            with open(PLAYER_STATE_PATH, 'r') as f:
                player_data = json.load(f)
        except Exception as e:
            print(f"    Could not read player state: {e}")
            player_data = {
                "_id": "5b4bb60260a9ba18c52834d8",
                "player-id": "5b4bb60260a9ba18c52834d8",
                "steam-id": "76561198286599994",
                "profile-name": "Player"
            }
        
        # CRITICAL: Game expects DRLPlayerProfileData[] - an ARRAY, not a single object
        # Wrap the player data in an array
        player_data_array = [player_data]
        
        encoded_data = base64.b64encode(json.dumps(player_data_array).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "encoded": True,  # CRITICAL: Tell game the data is base64 encoded
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def do_POST(self):
        """Handle POST requests"""
        path = self.path.split('?')[0]
        
        # Read POST body
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b''
        
        print(f"  POST: {self.path}")
        if post_data:
            try:
                print(f"    Body: {post_data.decode()[:200]}...")
            except:
                pass
        
        # Login service
        if 'login' in path:
            self.handle_login()
        
        # State endpoint (POST is used for read/write)
        elif '/state' in path:
            self.handle_state_post()
        
        # Storage services
        elif 'storage' in path:
            self.handle_storage()
        
        # Analytics/logs - just acknowledge
        elif 'analytics' in path or 'logs' in path or 'events' in path:
            self.handle_analytics()
        
        # Default
        else:
            self.handle_generic()
    
    def handle_time(self):
        """Return server time - raw JSON"""
        now = datetime.now(timezone.utc)
        inner_data = {
            "serverTime": now.isoformat(),
            "serverTimeMs": int(now.timestamp() * 1000),
            "timestamp": int(now.timestamp())
        }
        data = {
            "success": True,
            "message": None,
            "encoded": False,
            "data": inner_data  # Raw JSON, not Base64
        }
        self.send_json_response(data)
    
    def handle_login(self):
        """Return successful mock login matching DRL's expected format"""
        # Use a generic player ID
        player_id = "5b4bb60260a9ba18c52834d8"
        steam_id = "76561198286599994"
        
        # Inner data that will be Base64 encoded
        inner_data = {
            "_id": player_id,
            "player-id": player_id,
            "player": player_id,
            "steam-id": steam_id,
            "profile-name": "Player",
            "profile-photo-url": "",
            "profile-color": "88ffdf",
            "profile-country-iso": "US",
            "profile-language-iso": "english",
            "profile-score": "1",
            "branch-id": "public",
            "createdAt": "2018-07-15T21:33:22.692Z",
            "updatedAt": datetime.now(timezone.utc).isoformat(),
            "lastLogin": datetime.now(timezone.utc).isoformat(),
            "isAuthenticated": True,
            "isPremium": True,
            "clear-maps-cache": False
        }
        
        # Base64 encode the data
        encoded_data = base64.b64encode(json.dumps(inner_data).encode()).decode()
        
        # Create a mock JWT-like token (Base64 encoded payload)
        token_payload = {"userId": player_id, "exp": int(time.time()) + 86400}
        mock_token = base64.b64encode(json.dumps(token_payload).encode()).decode()
        
        # Login returns Base64 encoded data
        data = {
            "success": True,
            "message": None,
            "error": None,
            "token": mock_token,
            "refreshToken": mock_token,
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def handle_storage(self):
        """Handle storage requests - return player state or save data (Base64 encoded)"""
        path = self.path.lower()
        
        # If requesting player state, try to read the local offline state
        if 'player' in path or 'state' in path:
            try:
                with open(PLAYER_STATE_PATH, 'r') as f:
                    player_data = json.load(f)
                encoded_data = base64.b64encode(json.dumps(player_data).encode()).decode()
                data = {
                    "success": True,
                    "message": None,
                    "data": encoded_data
                }
                self.send_json_response(data)
                return
            except Exception as e:
                print(f"    Could not read player state: {e}")
        
        # Default storage response
        encoded_data = base64.b64encode(json.dumps({}).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def handle_analytics(self):
        """Acknowledge analytics/logging requests"""
        data = {
            "success": True,
            "message": None
        }
        self.send_json_response(data)
    
    def handle_content(self):
        """Handle content/maps requests - look up track by GUID if specified"""
        # Parse query params to check for guid
        from urllib.parse import urlparse, parse_qs
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        
        guid = params.get('guid', [None])[0]
        
        if guid:
            # Look up the FULL track data (including root scene) by guid
            track = FULL_TRACKS_BY_GUID.get(guid)
            
            if track:
                print(f"    Found FULL track: {track.get('map-title', 'Unknown')} for guid {guid}")
                # Return the full track data directly (not as array)
                data = {
                    "success": True,
                    "message": None,
                    "encoded": False,
                    "data": track
                }
            elif guid.startswith('CMP-'):
                # Custom map - check if CMP file exists and return stub metadata
                cmp_file = os.path.join(GAME_DIR, "DRL Simulator_Data/StreamingAssets/game/storage/offline/maps", f"{guid}.cmp")
                if os.path.exists(cmp_file):
                    print(f"    Found CMP file for: {guid}")
                    # Return stub metadata for custom map
                    stub_track = {
                        "guid": guid,
                        "map-id": "MP-custom",
                        "map-title": f"Custom Track",
                        "map-thumb": "",
                        "map-category": "MapCustom",
                        "map-difficulty": 2,
                        "map-distance": 1000,
                        "map-laps": 3,
                        "track-id": "race",
                        "is-public": True,
                        "is-race-allowed": True,
                        "is-drl-official": False,
                        "is-featured": False,
                        "is-custom": True,
                        "steam-id": "76561198286599994",
                        "profile-name": "Community",
                        "profile-color": "ffffff",
                        "profile-thumb": "",
                        "rating-count": 0,
                        "score": 0,
                        "created-at": "2024-01-01T00:00:00.000Z",
                        "updated-at": "2024-01-01T00:00:00.000Z",
                    }
                    data = {
                        "success": True,
                        "message": None,
                        "encoded": False,
                        "data": stub_track
                    }
                else:
                    print(f"    CMP file not found for: {guid}")
                    # Return stub even if file doesn't exist
                    stub_track = {
                        "guid": guid,
                        "map-id": "MP-unknown",
                        "map-title": "Unknown Track",
                        "map-thumb": "",
                        "map-category": "MapCustom",
                        "map-difficulty": 2,
                        "map-distance": 1000,
                        "map-laps": 3,
                        "track-id": "race",
                        "is-public": True,
                        "is-race-allowed": True,
                        "is-drl-official": False,
                        "is-featured": False,
                        "is-custom": True,
                        "steam-id": "",
                        "profile-name": "Unknown",
                        "profile-color": "888888",
                        "profile-thumb": "",
                        "rating-count": 0,
                        "score": 0,
                        "created-at": "2024-01-01T00:00:00.000Z",
                        "updated-at": "2024-01-01T00:00:00.000Z",
                    }
                    data = {
                        "success": True,
                        "message": None,
                        "encoded": False,
                        "data": stub_track
                    }
            else:
                print(f"    Track not found for guid: {guid}")
                data = {
                    "success": True,
                    "message": None,
                    "encoded": False,
                    "data": None
                }
        else:
            # No guid specified, return all tracks (metadata only)
            data = {
                "success": True,
                "message": None,
                "encoded": False,
                "data": ALL_TRACKS
            }
        self.send_json_response(data)
    
    def handle_content_manifest(self):
        """Return the content manifest with all available maps - Base64 encoded"""
        inner_data = {
            "version": "1.0.0",
            "maps": ALL_MAPS,
            "features": {
                "multiplayer": True,
                "mapEditor": True,
                "customTracks": True,
                "leaderboards": False,  # Offline mode
                "tournaments": False
            },
            "settings": {
                "maxPlayers": 8,
                "offlineMode": True
            }
        }
        encoded_data = base64.b64encode(json.dumps(inner_data).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data
        }
        self.send_json_response(data)
    
    def handle_generic(self):
        """Generic success response - Base64 encoded empty object"""
        encoded_data = base64.b64encode(json.dumps({}).encode()).decode()
        data = {
            "success": True,
            "message": None,
            "data": encoded_data
        }
        self.send_json_response(data)


def generate_self_signed_cert():
    """Generate self-signed certificate for HTTPS - works on Windows without OpenSSL"""
    import platform
    
    # Use temp directory appropriate for the OS
    if platform.system() == 'Windows':
        temp_dir = os.environ.get('TEMP', 'C:\\Temp')
    else:
        temp_dir = '/tmp'
    
    cert_path = os.path.join(temp_dir, 'drl_mock_cert.pem')
    key_path = os.path.join(temp_dir, 'drl_mock_key.pem')
    
    if os.path.exists(cert_path) and os.path.exists(key_path):
        return cert_path, key_path
    
    print("Generating self-signed certificate for HTTPS...")
    
    # Try using cryptography library first (pure Python, works everywhere)
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        from datetime import timedelta
        
        # Generate private key
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        
        # Generate certificate
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "api.drlgame.com"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "DRL Mock Server"),
        ])
        
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.now(timezone.utc))
            .not_valid_after(datetime.now(timezone.utc) + timedelta(days=365))
            .add_extension(
                x509.SubjectAlternativeName([x509.DNSName("api.drlgame.com")]),
                critical=False,
            )
            .sign(key, hashes.SHA256())
        )
        
        # Write key
        with open(key_path, "wb") as f:
            f.write(key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ))
        
        # Write certificate
        with open(cert_path, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))
        
        print(f"  Certificate: {cert_path}")
        print(f"  Key: {key_path}")
        return cert_path, key_path
        
    except ImportError:
        print("  Note: 'cryptography' package not installed, trying openssl...")
    
    # Fallback to openssl command (works on Linux/Mac)
    cmd = [
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', key_path, '-out', cert_path,
        '-days', '365', '-nodes',
        '-subj', '/CN=api.drlgame.com/O=DRL Mock Server'
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"  Certificate: {cert_path}")
        print(f"  Key: {key_path}")
        return cert_path, key_path
    except Exception as e:
        print(f"Warning: Could not generate certificate: {e}")
        print("  HTTPS will not work. Install 'cryptography' package:")
        print("    pip install cryptography")
        return None, None


def run_server(port=80, use_https=False):
    """Run the mock server"""
    server_address = ('0.0.0.0', port)
    httpd = HTTPServer(server_address, DRLMockHandler)
    
    if use_https:
        cert_path, key_path = generate_self_signed_cert()
        if cert_path and key_path:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert_path, key_path)
            httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
            print(f"Starting HTTPS mock server on port {port}...")
        else:
            print(f"Starting HTTP mock server on port {port} (HTTPS failed)...")
    else:
        print(f"Starting HTTP mock server on port {port}...")
    
    print(f"""
╔════════════════════════════════════════════════════════════════╗
║          DRL Simulator Mock Backend Server                     ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  To use this server, add to /etc/hosts:                        ║
║      127.0.0.1    api.drlgame.com                              ║
║                                                                ║
║  On Linux:                                                     ║
║      sudo sh -c 'echo "127.0.0.1 api.drlgame.com" >> /etc/hosts' ║
║                                                                ║
║  Then run this server and launch the game.                     ║
║                                                                ║
║  Press Ctrl+C to stop.                                         ║
╚════════════════════════════════════════════════════════════════╝
""")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.shutdown()


def run_dual_server():
    """Run both HTTP (80) and HTTPS (443) servers"""
    cert_path, key_path = generate_self_signed_cert()
    
    # HTTP server on port 80
    http_server = HTTPServer(('0.0.0.0', 80), DRLMockHandler)
    
    # HTTPS server on port 443
    https_server = HTTPServer(('0.0.0.0', 443), DRLMockHandler)
    if cert_path and key_path:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert_path, key_path)
        https_server.socket = context.wrap_socket(https_server.socket, server_side=True)
    
    print(f"""
╔════════════════════════════════════════════════════════════════╗
║          DRL Simulator Mock Backend Server                     ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Running on:                                                   ║
║      HTTP:  port 80                                            ║
║      HTTPS: port 443                                           ║
║                                                                ║
║  Maps enabled: {len(ALL_MAPS)} maps                                        ║
║                                                                ║
║  Add to /etc/hosts:                                            ║
║      127.0.0.1    api.drlgame.com                              ║
║                                                                ║
║  Press Ctrl+C to stop.                                         ║
╚════════════════════════════════════════════════════════════════╝
""")
    
    # Run HTTP server in a thread
    http_thread = threading.Thread(target=http_server.serve_forever)
    http_thread.daemon = True
    http_thread.start()
    
    # Run HTTPS server in main thread
    try:
        https_server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down servers...")
        http_server.shutdown()
        https_server.shutdown()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='DRL Simulator Mock Backend Server')
    parser.add_argument('--port', type=int, default=80, help='Port to run on (default: 80)')
    parser.add_argument('--https', action='store_true', help='Use HTTPS only (port 443)')
    parser.add_argument('--dual', action='store_true', help='Run both HTTP (80) and HTTPS (443)')
    parser.add_argument('--game-dir', type=str, help='Path to DRL Simulator installation')
    args = parser.parse_args()
    
    if args.game_dir:
        GAME_DIR = args.game_dir
        MAPS_DIR = os.path.join(GAME_DIR, "DRL Simulator_Data/StreamingAssets/game/content/maps")
        PLAYER_STATE_PATH = os.path.join(GAME_DIR, "DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json")
        ALL_TRACKS = load_all_tracks()
        FULL_TRACKS_BY_GUID = load_full_tracks_by_guid()
    
    if args.dual:
        run_dual_server()
    else:
        run_server(port=args.port, use_https=args.https)
