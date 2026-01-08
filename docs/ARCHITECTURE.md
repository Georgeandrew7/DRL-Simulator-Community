# DRL Simulator Community Multiplayer Architecture

## Overview

This document describes the architecture for community-hosted multiplayer for DRL Simulator after official server shutdown.

## Components

### 1. Steam Integration Layer
- Fetches Steam ID from the running Steam client
- Retrieves Steam profile photo URL
- Writes player data to `player-state.json`

### 2. P2P Game Hosting
- When a player creates a multiplayer session, they become the host
- Host's game runs as both client AND server (listen server model)
- Maximum capacity: 6 pilots + 15 spectators = 21 total

### 3. Master Server Coordinator
- Lightweight Python/Go service that runs centrally (or can be self-hosted)
- Maintains list of active game sessions
- Provides NAT punch-through assistance via STUN/TURN
- Does NOT route game traffic - only coordinates connections

### 4. Track Sharing System
- When host selects a custom track, it's advertised with the session
- Joining players check if they have the track
- If missing, track data is transferred from host to joiner
- Tracks stored in `StreamingAssets/game/content/maps/`

### 5. Game Mod (BepInEx Plugin)
- Hooks into PhotonNetwork to redirect to community servers
- Intercepts room creation to enable P2P hosting
- Handles player state synchronization (stick inputs, positions, etc.)
- Manages spectator camera modes

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     DRL Simulator (Modded)                       │
├─────────────────────────────────────────────────────────────────┤
│  BepInEx/MelonLoader Plugin                                     │
│  ├── Steam Integration (get Steam ID, avatar)                  │
│  ├── P2P Host Mode (listen server)                             │
│  ├── Track Sharing (send/receive custom maps)                  │
│  └── Photon Redirect (self-hosted or P2P)                      │
└─────────────────────────────────────────────────────────────────┘
           │                          │
           │ Register/Query           │ Direct P2P
           │ Sessions                 │ Game Traffic
           ▼                          ▼
┌──────────────────────┐    ┌──────────────────────┐
│   Master Coordinator  │    │   Other Players      │
│   (Python Server)     │    │   (P2P Connection)   │
│   - Session List      │    │                      │
│   - NAT Traversal     │    │                      │
│   - Player Discovery  │    │                      │
└──────────────────────┘    └──────────────────────┘
```

## Player State Structure

The game stores player data in:
`StreamingAssets/game/storage/offline/state/player/player-state.json`

Key fields we manage:
- `steam-id` - Steam ID (fetched from Steam API)
- `profile-photo-url` - Avatar URL from Steam
- `profile-name` - Display name
- `_id` - Unique player identifier
- `player-id` - Game's internal player ID

## Multiplayer Session Structure

```json
{
  "session_id": "uuid",
  "host": {
    "steam_id": "76561198848012403",
    "player_name": "Tydronious",
    "avatar_url": "https://avatars.steamstatic.com/...",
    "ip": "auto-detected",
    "port": 5056
  },
  "room": {
    "name": "Tydronious's Room",
    "map_id": "MP-0c6",
    "track_id": "CMP-12345...",
    "is_custom_track": true,
    "mode": "race"
  },
  "capacity": {
    "pilots": 6,
    "spectators": 15,
    "current_pilots": 1,
    "current_spectators": 0
  },
  "settings": {
    "laps": 3,
    "physics": "sim",
    "allow_track_download": true
  }
}
```

## Implementation Phases

### Phase 1: Steam Integration + Player State Writer
- Python tool that reads Steam client data
- Writes to player-state.json automatically
- Can run as standalone or integrated with mod

### Phase 2: Master Coordinator Server  
- List/Register/Query game sessions
- NAT traversal support via STUN
- WebSocket for real-time session updates

### Phase 3: BepInEx Plugin
- Hook into Photon networking
- Enable P2P hosting mode
- Player input/state synchronization

### Phase 4: Track Sharing
- Detect custom tracks on session join
- Transfer missing tracks from host
- Integrity verification (hash checking)
