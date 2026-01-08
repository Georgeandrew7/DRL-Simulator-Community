#!/usr/bin/env python3
"""
DRL Simulator - Steam Player Sync
Fetches Steam player info and writes to player-state.json

Features:
- Reads Steam ID from running Steam client
- Fetches profile photo from Steam API
- Updates player-state.json with current Steam info
- Generates unique player ID if needed
"""

import json
import os
import sys
import hashlib
import requests
import struct
import time
from pathlib import Path
from typing import Optional, Dict, Any
import uuid

# Steam Web API Key - Users should get their own from https://steamcommunity.com/dev/apikey
# For basic avatar fetching, we can use the public Steam Community API without a key
STEAM_API_KEY = os.environ.get('STEAM_API_KEY', '')

# Default paths
GAME_PATH = Path(__file__).parent.parent
PLAYER_STATE_PATH = GAME_PATH / "DRL Simulator_Data" / "StreamingAssets" / "game" / "storage" / "offline" / "state" / "player" / "player-state.json"

# Linux Steam paths
STEAM_CONFIG_PATHS = [
    Path.home() / ".steam" / "steam" / "config" / "loginusers.vdf",
    Path.home() / ".local" / "share" / "Steam" / "config" / "loginusers.vdf",
    Path.home() / ".var" / "app" / "com.valvesoftware.Steam" / ".steam" / "steam" / "config" / "loginusers.vdf",  # Flatpak
]

# Windows Steam paths (for Wine/Proton compatibility)
WINE_STEAM_PATHS = [
    Path.home() / ".steam" / "steam" / "steamapps" / "compatdata" / "641780" / "pfx" / "drive_c" / "Program Files (x86)" / "Steam" / "config" / "loginusers.vdf",
]


def get_steam_id_from_config() -> Optional[str]:
    """
    Read Steam ID from Steam's loginusers.vdf file
    Returns the most recently logged in user's Steam ID
    """
    for config_path in STEAM_CONFIG_PATHS + WINE_STEAM_PATHS:
        if config_path.exists():
            print(f"[Steam] Found config: {config_path}")
            try:
                content = config_path.read_text()
                # Parse VDF format (simple regex approach)
                import re
                # Find Steam64 IDs (17-digit numbers)
                steam_ids = re.findall(r'"(\d{17})"', content)
                if steam_ids:
                    # Get the most recent (usually first one that's logged in)
                    for steam_id in steam_ids:
                        # Check if this user was recently active
                        if f'"{steam_id}"' in content:
                            # Look for MostRecent flag
                            pattern = rf'"{steam_id}"\s*\{{\s*[^}}]*"MostRecent"\s*"1"'
                            if re.search(pattern, content, re.DOTALL):
                                print(f"[Steam] Found most recent Steam ID: {steam_id}")
                                return steam_id
                    # If no MostRecent, return first
                    print(f"[Steam] Using first Steam ID: {steam_ids[0]}")
                    return steam_ids[0]
            except Exception as e:
                print(f"[Steam] Error reading {config_path}: {e}")
    
    return None


def get_steam_id_from_env() -> Optional[str]:
    """Check environment variables for Steam ID"""
    return os.environ.get('STEAM_ID') or os.environ.get('SteamAppUser')


def get_steam_id_from_game_state() -> Optional[str]:
    """Read existing Steam ID from player-state.json"""
    if PLAYER_STATE_PATH.exists():
        try:
            state = json.loads(PLAYER_STATE_PATH.read_text())
            return state.get('steam-id')
        except:
            pass
    return None


def get_steam_profile(steam_id: str) -> Dict[str, Any]:
    """
    Fetch Steam profile info using public Steam Community API
    Returns dict with personaname, avatarfull, etc.
    """
    profile = {
        'steam_id': steam_id,
        'name': f'Player_{steam_id[-6:]}',
        'avatar_url': '',
    }
    
    # Try Steam Web API if key available
    if STEAM_API_KEY:
        try:
            url = f"https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key={STEAM_API_KEY}&steamids={steam_id}"
            resp = requests.get(url, timeout=10)
            data = resp.json()
            if data.get('response', {}).get('players'):
                player = data['response']['players'][0]
                profile['name'] = player.get('personaname', profile['name'])
                profile['avatar_url'] = player.get('avatarfull', '')
                print(f"[Steam] Got profile via API: {profile['name']}")
                return profile
        except Exception as e:
            print(f"[Steam] API request failed: {e}")
    
    # Fallback: Scrape Steam Community profile
    try:
        url = f"https://steamcommunity.com/profiles/{steam_id}/?xml=1"
        resp = requests.get(url, timeout=10)
        if resp.status_code == 200:
            import re
            # Parse XML response
            name_match = re.search(r'<steamID><!\[CDATA\[(.*?)\]\]></steamID>', resp.text)
            avatar_match = re.search(r'<avatarFull><!\[CDATA\[(.*?)\]\]></avatarFull>', resp.text)
            
            if name_match:
                profile['name'] = name_match.group(1)
            if avatar_match:
                profile['avatar_url'] = avatar_match.group(1)
            
            print(f"[Steam] Got profile via Community XML: {profile['name']}")
    except Exception as e:
        print(f"[Steam] Community profile fetch failed: {e}")
    
    return profile


def generate_player_id(steam_id: str) -> str:
    """
    Generate a unique player ID based on Steam ID
    Format similar to original DRL player IDs (24 char hex)
    """
    # Create a deterministic but unique ID from Steam ID
    hash_input = f"drl-community-{steam_id}"
    hash_bytes = hashlib.sha256(hash_input.encode()).digest()
    return hash_bytes[:12].hex()


def generate_mongo_like_id() -> str:
    """Generate an ID similar to MongoDB ObjectId format"""
    import time
    timestamp = int(time.time())
    random_bytes = os.urandom(8)
    return f"{timestamp:08x}{random_bytes.hex()}"


def update_player_state(steam_id: str, profile: Dict[str, Any]) -> bool:
    """
    Update player-state.json with Steam profile info
    Preserves existing game data while updating player identity
    """
    state = {}
    
    # Load existing state if present
    if PLAYER_STATE_PATH.exists():
        try:
            state = json.loads(PLAYER_STATE_PATH.read_text())
            print(f"[PlayerState] Loaded existing state with {len(state)} fields")
        except Exception as e:
            print(f"[PlayerState] Error loading existing state: {e}")
            # Create backup of corrupted file
            backup_path = PLAYER_STATE_PATH.with_suffix('.json.bak')
            if PLAYER_STATE_PATH.exists():
                PLAYER_STATE_PATH.rename(backup_path)
    
    # Update player identity fields
    state['steam-id'] = steam_id
    state['profile-name'] = profile['name']
    state['profile-photo-url'] = profile['avatar_url']
    
    # Generate player ID if not present
    if not state.get('player-id'):
        state['player-id'] = generate_player_id(steam_id)
        print(f"[PlayerState] Generated player-id: {state['player-id']}")
    
    if not state.get('_id'):
        state['_id'] = generate_mongo_like_id()
        print(f"[PlayerState] Generated _id: {state['_id']}")
    
    # Update timestamps
    state['lastLogin'] = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
    if not state.get('createdAt'):
        state['createdAt'] = state['lastLogin']
    state['updatedAt'] = state['lastLogin']
    
    # Ensure directory exists
    PLAYER_STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    
    # Write updated state
    try:
        PLAYER_STATE_PATH.write_text(json.dumps(state))
        print(f"[PlayerState] Saved to {PLAYER_STATE_PATH}")
        return True
    except Exception as e:
        print(f"[PlayerState] Error saving: {e}")
        return False


def main():
    print("=" * 60)
    print("DRL Simulator - Steam Player Sync")
    print("=" * 60)
    
    # Try to get Steam ID from various sources
    steam_id = None
    
    # Priority: Environment > Config file > Existing state
    steam_id = get_steam_id_from_env()
    if steam_id:
        print(f"[Steam] Using Steam ID from environment: {steam_id}")
    
    if not steam_id:
        steam_id = get_steam_id_from_config()
    
    if not steam_id:
        steam_id = get_steam_id_from_game_state()
        if steam_id:
            print(f"[Steam] Using existing Steam ID from player state: {steam_id}")
    
    if not steam_id:
        print("[Error] Could not determine Steam ID!")
        print("\nPlease set the STEAM_ID environment variable:")
        print("  export STEAM_ID=76561198xxxxxxxxx")
        print("\nOr run this after Steam is logged in.")
        sys.exit(1)
    
    print(f"\n[Steam] Steam ID: {steam_id}")
    
    # Fetch Steam profile
    print("\n[Steam] Fetching profile info...")
    profile = get_steam_profile(steam_id)
    print(f"[Steam] Name: {profile['name']}")
    print(f"[Steam] Avatar: {profile['avatar_url'][:50]}..." if profile['avatar_url'] else "[Steam] No avatar URL")
    
    # Update player state
    print("\n[PlayerState] Updating player-state.json...")
    if update_player_state(steam_id, profile):
        print("\n✓ Player state updated successfully!")
    else:
        print("\n✗ Failed to update player state")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("Steam sync complete! You can now launch the game.")
    print("=" * 60)


if __name__ == "__main__":
    main()
