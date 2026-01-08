#!/usr/bin/env python3
"""
DRL Simulator - Track Sharing Server
Handles sharing custom tracks between players during P2P sessions

Features:
- Serves track data to joining players
- Verifies track integrity via hashes
- Handles both map base files and custom track overlays
- Compresses track data for efficient transfer
"""

import asyncio
import hashlib
import json
import os
import zipfile
from io import BytesIO
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass
import logging

try:
    from aiohttp import web
except ImportError:
    print("Please install aiohttp: pip install aiohttp")
    exit(1)

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

# Paths
GAME_PATH = Path(__file__).parent.parent
MAPS_PATH = GAME_PATH / "DRL Simulator_Data" / "StreamingAssets" / "game" / "content" / "maps"
CUSTOM_TRACKS_PATH = MAPS_PATH  # Custom tracks stored within map folders


@dataclass
class TrackInfo:
    map_id: str
    track_id: str
    name: str
    author: str
    is_custom: bool
    file_hash: str
    file_size: int
    files: List[str]


class TrackManager:
    """Manages track discovery and packaging"""
    
    def __init__(self, maps_path: Path):
        self.maps_path = maps_path
        self.tracks_cache: Dict[str, TrackInfo] = {}
        self.scan_tracks()
    
    def scan_tracks(self):
        """Scan for all available tracks"""
        logger.info(f"Scanning tracks in {self.maps_path}")
        
        if not self.maps_path.exists():
            logger.warning(f"Maps path does not exist: {self.maps_path}")
            return
        
        for map_dir in self.maps_path.iterdir():
            if not map_dir.is_dir():
                continue
            
            map_id = map_dir.name
            
            # Check for custom tracks folder
            custom_dir = map_dir / "custom"
            if custom_dir.exists():
                for track_dir in custom_dir.iterdir():
                    if track_dir.is_dir():
                        track_id = track_dir.name
                        track_info = self._scan_track(map_id, track_id, track_dir, is_custom=True)
                        if track_info:
                            key = f"{map_id}/{track_id}"
                            self.tracks_cache[key] = track_info
            
            # Check for built-in tracks (JSON files)
            for track_file in map_dir.glob("*.json"):
                track_id = track_file.stem
                track_info = self._scan_builtin_track(map_id, track_id, track_file)
                if track_info:
                    key = f"{map_id}/{track_id}"
                    self.tracks_cache[key] = track_info
        
        logger.info(f"Found {len(self.tracks_cache)} tracks")
    
    def _scan_track(self, map_id: str, track_id: str, track_dir: Path, 
                    is_custom: bool = False) -> Optional[TrackInfo]:
        """Scan a track directory and gather info"""
        try:
            files = []
            total_size = 0
            hash_data = []
            
            for file_path in track_dir.rglob("*"):
                if file_path.is_file():
                    rel_path = str(file_path.relative_to(track_dir))
                    files.append(rel_path)
                    total_size += file_path.stat().st_size
                    
                    # Include file hash in overall hash
                    file_hash = hashlib.md5(file_path.read_bytes()).hexdigest()
                    hash_data.append(f"{rel_path}:{file_hash}")
            
            # Calculate overall track hash
            overall_hash = hashlib.sha256("\n".join(sorted(hash_data)).encode()).hexdigest()
            
            # Try to get track name from metadata
            name = track_id
            author = "Unknown"
            meta_file = track_dir / "meta.json"
            if meta_file.exists():
                try:
                    meta = json.loads(meta_file.read_text())
                    name = meta.get("name", name)
                    author = meta.get("author", author)
                except:
                    pass
            
            return TrackInfo(
                map_id=map_id,
                track_id=track_id,
                name=name,
                author=author,
                is_custom=is_custom,
                file_hash=overall_hash,
                file_size=total_size,
                files=files
            )
        except Exception as e:
            logger.error(f"Error scanning track {map_id}/{track_id}: {e}")
            return None
    
    def _scan_builtin_track(self, map_id: str, track_id: str, 
                             track_file: Path) -> Optional[TrackInfo]:
        """Scan a built-in track (single JSON file)"""
        try:
            content = track_file.read_bytes()
            file_hash = hashlib.sha256(content).hexdigest()
            
            return TrackInfo(
                map_id=map_id,
                track_id=track_id,
                name=track_id,
                author="DRL Official",
                is_custom=False,
                file_hash=file_hash,
                file_size=len(content),
                files=[track_file.name]
            )
        except Exception as e:
            logger.error(f"Error scanning builtin track {map_id}/{track_id}: {e}")
            return None
    
    def get_track(self, map_id: str, track_id: str) -> Optional[TrackInfo]:
        """Get track info by ID"""
        key = f"{map_id}/{track_id}"
        return self.tracks_cache.get(key)
    
    def has_track(self, map_id: str, track_id: str, expected_hash: str = None) -> bool:
        """Check if we have a track, optionally verifying hash"""
        track = self.get_track(map_id, track_id)
        if not track:
            return False
        if expected_hash and track.file_hash != expected_hash:
            return False
        return True
    
    def package_track(self, map_id: str, track_id: str) -> Optional[bytes]:
        """Package a track into a zip file for transfer"""
        track = self.get_track(map_id, track_id)
        if not track:
            return None
        
        try:
            buffer = BytesIO()
            with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
                if track.is_custom:
                    track_dir = self.maps_path / map_id / "custom" / track_id
                    for file_path in track_dir.rglob("*"):
                        if file_path.is_file():
                            arc_name = str(file_path.relative_to(track_dir))
                            zf.write(file_path, arc_name)
                else:
                    # Built-in track (single file)
                    track_file = self.maps_path / map_id / f"{track_id}.json"
                    if track_file.exists():
                        zf.write(track_file, track_file.name)
            
            return buffer.getvalue()
        except Exception as e:
            logger.error(f"Error packaging track {map_id}/{track_id}: {e}")
            return None
    
    def install_track(self, map_id: str, track_id: str, data: bytes) -> bool:
        """Install a track from received zip data"""
        try:
            if track_id.startswith("CMP-"):
                # Custom track
                track_dir = self.maps_path / map_id / "custom" / track_id
            else:
                # Built-in track format
                track_dir = self.maps_path / map_id
            
            track_dir.mkdir(parents=True, exist_ok=True)
            
            with zipfile.ZipFile(BytesIO(data), 'r') as zf:
                zf.extractall(track_dir)
            
            logger.info(f"Installed track: {map_id}/{track_id}")
            
            # Refresh cache
            self.scan_tracks()
            return True
        except Exception as e:
            logger.error(f"Error installing track: {e}")
            return False
    
    def list_tracks(self, map_id: str = None) -> List[dict]:
        """List all tracks, optionally filtered by map"""
        tracks = []
        for key, track in self.tracks_cache.items():
            if map_id and track.map_id != map_id:
                continue
            tracks.append({
                'map_id': track.map_id,
                'track_id': track.track_id,
                'name': track.name,
                'author': track.author,
                'is_custom': track.is_custom,
                'file_hash': track.file_hash,
                'file_size': track.file_size,
            })
        return tracks


# Global track manager
track_manager: TrackManager = None


# HTTP Handlers
async def list_tracks(request):
    """GET /tracks - List all available tracks"""
    map_id = request.query.get('map_id')
    tracks = track_manager.list_tracks(map_id=map_id)
    return web.json_response({'tracks': tracks})


async def get_track_info(request):
    """GET /tracks/<map_id>/<track_id> - Get track info"""
    map_id = request.match_info['map_id']
    track_id = request.match_info['track_id']
    
    track = track_manager.get_track(map_id, track_id)
    if not track:
        return web.json_response({'error': 'Track not found'}, status=404)
    
    return web.json_response({
        'map_id': track.map_id,
        'track_id': track.track_id,
        'name': track.name,
        'author': track.author,
        'is_custom': track.is_custom,
        'file_hash': track.file_hash,
        'file_size': track.file_size,
        'files': track.files,
    })


async def check_track(request):
    """POST /tracks/check - Check if we have a track"""
    try:
        data = await request.json()
    except:
        return web.json_response({'error': 'Invalid JSON'}, status=400)
    
    map_id = data.get('map_id')
    track_id = data.get('track_id')
    expected_hash = data.get('hash')
    
    has_it = track_manager.has_track(map_id, track_id, expected_hash)
    
    return web.json_response({
        'has_track': has_it,
        'map_id': map_id,
        'track_id': track_id,
    })


async def download_track(request):
    """GET /tracks/<map_id>/<track_id>/download - Download track as zip"""
    map_id = request.match_info['map_id']
    track_id = request.match_info['track_id']
    
    data = track_manager.package_track(map_id, track_id)
    if not data:
        return web.json_response({'error': 'Track not found'}, status=404)
    
    return web.Response(
        body=data,
        content_type='application/zip',
        headers={
            'Content-Disposition': f'attachment; filename="{map_id}_{track_id}.zip"'
        }
    )


async def upload_track(request):
    """POST /tracks/<map_id>/<track_id>/upload - Upload a track"""
    map_id = request.match_info['map_id']
    track_id = request.match_info['track_id']
    
    data = await request.read()
    if not data:
        return web.json_response({'error': 'No data received'}, status=400)
    
    if track_manager.install_track(map_id, track_id, data):
        return web.json_response({'status': 'installed'})
    return web.json_response({'error': 'Installation failed'}, status=500)


def create_app(maps_path: Path):
    """Create the web application"""
    global track_manager
    track_manager = TrackManager(maps_path)
    
    app = web.Application()
    app.router.add_get('/tracks', list_tracks)
    app.router.add_get('/tracks/{map_id}/{track_id}', get_track_info)
    app.router.add_get('/tracks/{map_id}/{track_id}/download', download_track)
    app.router.add_post('/tracks/{map_id}/{track_id}/upload', upload_track)
    app.router.add_post('/tracks/check', check_track)
    
    return app


async def main():
    import argparse
    parser = argparse.ArgumentParser(description='DRL Track Sharing Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8081, help='Port to listen on')
    parser.add_argument('--maps-path', type=str, default=str(MAPS_PATH),
                       help='Path to maps directory')
    args = parser.parse_args()
    
    app = create_app(Path(args.maps_path))
    
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, args.host, args.port)
    await site.start()
    
    logger.info(f"=" * 60)
    logger.info(f"DRL Track Sharing Server")
    logger.info(f"=" * 60)
    logger.info(f"Tracks API: http://{args.host}:{args.port}/tracks")
    logger.info(f"Maps Path:  {args.maps_path}")
    logger.info(f"=" * 60)
    
    await asyncio.Event().wait()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Shutting down...")
