#!/usr/bin/env python3
"""
DRL Simulator Game Directory Finder

Auto-detects DRL Simulator installation regardless of:
- Steam vs Epic Games vs custom install
- Different drives (C:, D:, E:, etc.)
- Custom installation directories

Search order:
1. DRL_GAME_DIR environment variable
2. Windows Registry (Steam and Epic Games)
3. Steam library folders from libraryfolders.vdf
4. Epic Games manifest files
5. Common install paths (Steam, Epic, custom)
6. Drive scan for game executable
"""

import os
import json
import platform
import glob
import re


def find_game_directory():
    """
    Find DRL Simulator installation directory.
    Works with Steam, Epic Games, and custom installations.
    """
    system = platform.system()
    
    print("Searching for DRL Simulator installation...")
    
    # Check environment variable first (highest priority)
    env_dir = os.environ.get('DRL_GAME_DIR')
    if env_dir and os.path.exists(env_dir):
        print(f"  Found via DRL_GAME_DIR environment variable: {env_dir}")
        return env_dir
    
    if system == 'Windows':
        return _find_game_windows()
    elif system == 'Darwin':
        return _find_game_macos()
    else:
        return _find_game_linux()


def _find_game_windows():
    """Find DRL Simulator on Windows - Steam, Epic, or custom install"""
    
    # 1. Try Windows Registry for Steam install
    try:
        import winreg
        
        # Check Steam install path via Steam registry
        try:
            key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 
                r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 641780")
            install_path, _ = winreg.QueryValueEx(key, "InstallLocation")
            winreg.CloseKey(key)
            if install_path and os.path.exists(install_path):
                print(f"  Found via Windows Registry (Steam): {install_path}")
                return install_path
        except:
            pass
        
        # Check for Epic Games install via Uninstall registry
        try:
            for reg_path in [
                r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            ]:
                try:
                    key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, reg_path)
                    i = 0
                    while True:
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            # Check for DRL-related entries
                            if any(x in subkey_name.upper() for x in ['DRL', 'DRONE RACING']):
                                subkey = winreg.OpenKey(key, subkey_name)
                                try:
                                    install_path, _ = winreg.QueryValueEx(subkey, "InstallLocation")
                                    if install_path and os.path.exists(install_path):
                                        # Verify it's actually DRL Simulator
                                        if os.path.exists(os.path.join(install_path, "DRL Simulator.exe")):
                                            print(f"  Found via Windows Registry (Epic/Other): {install_path}")
                                            winreg.CloseKey(subkey)
                                            winreg.CloseKey(key)
                                            return install_path
                                except:
                                    pass
                                winreg.CloseKey(subkey)
                            i += 1
                        except OSError:
                            break
                    winreg.CloseKey(key)
                except:
                    pass
        except:
            pass
            
    except ImportError:
        pass  # winreg not available (shouldn't happen on Windows)
    
    # 2. Parse Steam libraryfolders.vdf for all Steam library locations
    steam_library_paths = []
    steam_paths_to_check = [
        os.path.expandvars(r"%ProgramFiles(x86)%\Steam"),
        os.path.expandvars(r"%ProgramFiles%\Steam"),
        r"C:\Steam",
    ]
    
    # Add all drives with common Steam locations
    for drive in "CDEFGHIJKLMNOPQRSTUVWXYZ":
        steam_paths_to_check.extend([
            f"{drive}:\\Steam",
            f"{drive}:\\SteamLibrary",
            f"{drive}:\\Games\\Steam",
            f"{drive}:\\Games\\SteamLibrary",
            f"{drive}:\\Program Files\\Steam",
            f"{drive}:\\Program Files (x86)\\Steam",
        ])
    
    for steam_path in steam_paths_to_check:
        vdf_path = os.path.join(steam_path, "steamapps", "libraryfolders.vdf")
        if os.path.exists(vdf_path):
            try:
                with open(vdf_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                # Simple VDF parsing - look for "path" entries
                paths = re.findall(r'"path"\s+"([^"]+)"', content)
                steam_library_paths.extend(paths)
                # Also add the Steam install itself
                steam_library_paths.append(steam_path)
            except:
                pass
    
    # Check all Steam library paths for DRL Simulator
    for lib_path in steam_library_paths:
        game_path = os.path.join(lib_path, "steamapps", "common", "DRL Simulator")
        if os.path.exists(game_path):
            print(f"  Found via Steam library: {game_path}")
            return game_path
    
    # 3. Check Epic Games install locations
    
    # Epic Games default manifest location
    epic_manifests_dir = os.path.expandvars(r"%ProgramData%\Epic\EpicGamesLauncher\Data\Manifests")
    if os.path.exists(epic_manifests_dir):
        for manifest_file in glob.glob(os.path.join(epic_manifests_dir, "*.item")):
            try:
                with open(manifest_file, 'r', encoding='utf-8') as f:
                    manifest = json.load(f)
                display_name = manifest.get('DisplayName', '').lower()
                # Check for various game names
                if any(x in display_name for x in ['drl', 'drone racing', 'drone race']):
                    install_path = manifest.get('InstallLocation', '')
                    if install_path and os.path.exists(install_path):
                        print(f"  Found via Epic Games manifest: {install_path}")
                        return install_path
            except:
                pass
    
    # Common Epic Games install locations
    epic_paths_to_check = []
    for drive in "CDEFGHIJKLMNOPQRSTUVWXYZ":
        epic_paths_to_check.extend([
            f"{drive}:\\Program Files\\Epic Games\\DRL Simulator",
            f"{drive}:\\Program Files\\Epic Games\\DRLSimulator",
            f"{drive}:\\Program Files\\Epic Games\\TheDroneRacingLeagueSimulator",
            f"{drive}:\\Epic Games\\DRL Simulator",
            f"{drive}:\\Epic Games\\DRLSimulator",
            f"{drive}:\\Epic Games\\TheDroneRacingLeagueSimulator",
            f"{drive}:\\Games\\Epic Games\\DRL Simulator",
            f"{drive}:\\Games\\DRL Simulator",
        ])
    
    for path in epic_paths_to_check:
        if os.path.exists(path):
            # Verify it has the game executable
            if os.path.exists(os.path.join(path, "DRL Simulator.exe")):
                print(f"  Found via Epic Games common path: {path}")
                return path
    
    # 4. Common Steam paths (fallback)
    steam_common_paths = [
        os.path.expandvars(r"%ProgramFiles(x86)%\Steam\steamapps\common\DRL Simulator"),
        os.path.expandvars(r"%ProgramFiles%\Steam\steamapps\common\DRL Simulator"),
    ]
    
    for drive in "CDEFGHIJKLMNOPQRSTUVWXYZ":
        steam_common_paths.extend([
            f"{drive}:\\Steam\\steamapps\\common\\DRL Simulator",
            f"{drive}:\\SteamLibrary\\steamapps\\common\\DRL Simulator",
            f"{drive}:\\Games\\Steam\\steamapps\\common\\DRL Simulator",
            f"{drive}:\\Games\\SteamLibrary\\steamapps\\common\\DRL Simulator",
            f"{drive}:\\Program Files\\Steam\\steamapps\\common\\DRL Simulator",
            f"{drive}:\\Program Files (x86)\\Steam\\steamapps\\common\\DRL Simulator",
        ])
    
    for path in steam_common_paths:
        if os.path.exists(path):
            print(f"  Found via Steam common path: {path}")
            return path
    
    # 5. Last resort: scan all drives for the game executable
    print("  Scanning drives for DRL Simulator...")
    for drive in "CDEFGHIJKLMNOPQRSTUVWXYZ":
        drive_root = f"{drive}:\\"
        if not os.path.exists(drive_root):
            continue
        
        # Look for common game folder patterns
        search_patterns = [
            f"{drive}:\\*\\DRL Simulator\\DRL Simulator.exe",
            f"{drive}:\\*\\*\\DRL Simulator\\DRL Simulator.exe",
            f"{drive}:\\*\\*\\*\\DRL Simulator\\DRL Simulator.exe",
            f"{drive}:\\*\\*\\*\\*\\DRL Simulator\\DRL Simulator.exe",
        ]
        
        for pattern in search_patterns:
            try:
                matches = glob.glob(pattern)
                if matches:
                    game_dir = os.path.dirname(matches[0])
                    print(f"  Found via drive scan: {game_dir}")
                    return game_dir
            except:
                pass
    
    # Return default (will show warning)
    print("  WARNING: Could not find DRL Simulator installation!")
    print("  Set DRL_GAME_DIR environment variable to your install path")
    print("  Example: set DRL_GAME_DIR=D:\\Games\\DRL Simulator")
    return r"C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator"


def _find_game_macos():
    """Find DRL Simulator on macOS"""
    possible_paths = [
        os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/DRL Simulator"),
        "/Applications/DRL Simulator.app/Contents/Resources",
    ]
    
    # Check Steam libraryfolders.vdf
    vdf_path = os.path.expanduser("~/Library/Application Support/Steam/steamapps/libraryfolders.vdf")
    if os.path.exists(vdf_path):
        try:
            with open(vdf_path, 'r') as f:
                content = f.read()
            paths = re.findall(r'"path"\s+"([^"]+)"', content)
            for lib_path in paths:
                game_path = os.path.join(lib_path, "steamapps", "common", "DRL Simulator")
                possible_paths.insert(0, game_path)
        except:
            pass
    
    for path in possible_paths:
        if os.path.exists(path):
            print(f"  Found: {path}")
            return path
    
    print("  WARNING: Could not find DRL Simulator installation!")
    return os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/DRL Simulator")


def _find_game_linux():
    """Find DRL Simulator on Linux"""
    possible_paths = [
        os.path.expanduser("~/.local/share/Steam/steamapps/common/DRL Simulator"),
        os.path.expanduser("~/.steam/steam/steamapps/common/DRL Simulator"),
        os.path.expanduser("~/.steam/root/steamapps/common/DRL Simulator"),
    ]
    
    # Check Steam libraryfolders.vdf for additional library locations
    vdf_paths = [
        os.path.expanduser("~/.local/share/Steam/steamapps/libraryfolders.vdf"),
        os.path.expanduser("~/.steam/steam/steamapps/libraryfolders.vdf"),
    ]
    
    for vdf_path in vdf_paths:
        if os.path.exists(vdf_path):
            try:
                with open(vdf_path, 'r') as f:
                    content = f.read()
                paths = re.findall(r'"path"\s+"([^"]+)"', content)
                for lib_path in paths:
                    game_path = os.path.join(lib_path, "steamapps", "common", "DRL Simulator")
                    possible_paths.insert(0, game_path)
            except:
                pass
    
    for path in possible_paths:
        if os.path.exists(path):
            print(f"  Found: {path}")
            return path
    
    print("  WARNING: Could not find DRL Simulator installation!")
    return os.path.expanduser("~/.local/share/Steam/steamapps/common/DRL Simulator")


# For testing
if __name__ == "__main__":
    game_dir = find_game_directory()
    print(f"\nGame directory: {game_dir}")
    print(f"  Exists: {os.path.exists(game_dir)}")
    
    maps_dir = os.path.join(game_dir, "DRL Simulator_Data", "StreamingAssets", "game", "content", "maps")
    print(f"\nMaps directory: {maps_dir}")
    print(f"  Exists: {os.path.exists(maps_dir)}")
