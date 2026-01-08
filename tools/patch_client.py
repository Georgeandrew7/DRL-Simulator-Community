#!/usr/bin/env python3
"""
DRL Simulator Client Patcher for Self-Hosted Server

This script modifies the PhotonServerSettings in resources.assets to:
1. Change HostingOption from PhotonCloud to SelfHosted
2. Update the server address to your self-hosted server

BACKUP YOUR FILES BEFORE RUNNING THIS!
"""

import UnityPy
import os
import sys
import shutil
import struct

GAME_PATH = "/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data"

def print_current_settings():
    """Display current PhotonServerSettings configuration."""
    file_path = os.path.join(GAME_PATH, "resources.assets")
    env = UnityPy.load(file_path)
    
    for obj in env.objects:
        if obj.type.name == "MonoBehaviour":
            raw = obj.get_raw_data()
            raw_str = raw.decode('latin-1', errors='ignore')
            
            if 'PhotonServerSettings' in raw_str:
                print("\n=== Current PhotonServerSettings ===")
                print(f"Raw data size: {len(raw)} bytes")
                
                # Parse the structure
                # Based on our hex dump analysis:
                # Offset 0x14: Length prefix (20 bytes) + "PhotonServerSettings"
                # Offset 0x34: Length prefix (36 bytes) + AppId GUID 1
                # Offset 0x5C: Length prefix (36 bytes) + AppId GUID 2
                # Offset 0x88: Various settings including hosting mode
                
                try:
                    # Read AppIds
                    app_id_1_len = struct.unpack('<I', raw[0x30:0x34])[0]
                    app_id_1 = raw[0x34:0x34+app_id_1_len].decode('latin-1')
                    
                    offset = 0x34 + app_id_1_len
                    # Align to 4 bytes
                    while offset % 4 != 0:
                        offset += 1
                    
                    app_id_2_len = struct.unpack('<I', raw[offset:offset+4])[0]
                    app_id_2 = raw[offset+4:offset+4+app_id_2_len].decode('latin-1')
                    
                    print(f"\nApp ID 1: {app_id_1}")
                    print(f"App ID 2: {app_id_2}")
                    
                    # Read port (at offset ~0x9C based on hex dump, little-endian)
                    port_offset = 0x98  # Approximate
                    port = struct.unpack('<H', raw[port_offset:port_offset+2])[0]
                    print(f"Port (approx): {port}")
                    
                except Exception as e:
                    print(f"Error parsing structure: {e}")
                
                # Print hex dump of key areas
                print("\n=== Hex dump of settings area (0x80-0xC0) ===")
                for i in range(0x80, min(0xC0, len(raw)), 16):
                    chunk = raw[i:i+16]
                    hex_part = ' '.join(f'{b:02x}' for b in chunk)
                    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                    print(f"{i:04x}: {hex_part:<48} {ascii_part}")
                
                return raw
    
    print("PhotonServerSettings not found!")
    return None

def find_hosting_option_offset(raw_data):
    """
    Try to find the hosting option field in the raw data.
    
    HostingOption enum values (typically):
    - 0: NotSet
    - 1: PhotonCloud
    - 2: SelfHosted
    - 3: OfflineMode
    
    We're looking for a byte that's currently 1 (PhotonCloud) that we want to change to 2 (SelfHosted)
    """
    # Based on standard Photon Unity serialization, the hosting option is usually
    # early in the settings after the AppIds
    
    # The structure seems to be:
    # - Header (script reference, name)
    # - AppId (string)
    # - AppIdChat or AppIdVoice (string)  
    # - HostingOption (int32)
    # - ...other settings...
    
    # From the hex dump, after the two GUIDs at ~0x34 and ~0x60,
    # there should be the hosting option around 0x88-0x90
    
    possible_offsets = []
    
    # Look for single-byte or 4-byte values of 1 (PhotonCloud) in the typical range
    for offset in range(0x80, 0xA0):
        if offset + 4 <= len(raw_data):
            val = struct.unpack('<I', raw_data[offset:offset+4])[0]
            if val in [0, 1, 2, 3]:  # Valid HostingOption values
                possible_offsets.append((offset, val))
    
    return possible_offsets

def create_patched_client(server_ip, server_port=5055):
    """
    Create a patched version of resources.assets that points to a self-hosted server.
    
    This is a reference implementation - actual patching requires:
    1. Understanding the exact binary format
    2. Updating the hosting mode
    3. Inserting the server address
    4. Updating asset checksums if required
    """
    
    file_path = os.path.join(GAME_PATH, "resources.assets")
    backup_path = file_path + ".backup"
    
    # Create backup
    if not os.path.exists(backup_path):
        print(f"Creating backup: {backup_path}")
        shutil.copy2(file_path, backup_path)
    
    print("\n=== Analyzing PhotonServerSettings ===")
    raw_data = print_current_settings()
    
    if raw_data is None:
        return False
    
    print("\n=== Possible HostingOption locations ===")
    offsets = find_hosting_option_offset(raw_data)
    for offset, val in offsets:
        option_names = {0: "NotSet", 1: "PhotonCloud", 2: "SelfHosted", 3: "OfflineMode"}
        print(f"  Offset 0x{offset:04x}: Value {val} ({option_names.get(val, 'Unknown')})")
    
    print("\n" + "=" * 60)
    print("MANUAL PATCHING INSTRUCTIONS")
    print("=" * 60)
    print("""
To patch the game client for self-hosting:

OPTION 1: Use dnSpy (Recommended)
---------------------------------
1. Download dnSpy: https://github.com/dnSpy/dnSpy
2. Open DRL Simulator_Data/Managed/Assembly-CSharp.dll
3. Search for "PhotonServerSettings" class
4. Find where it's initialized/loaded
5. Modify the code to:
   - Set HostType to SelfHosted (usually enum value 2)
   - Set MasterServerAddress to your server IP
   - Set MasterServerPort to 5055

OPTION 2: Use UABE (Unity Asset Bundle Extractor)
------------------------------------------------
1. Download UABE: https://github.com/SeriousCache/UABE
2. Open resources.assets
3. Find PhotonServerSettings MonoBehaviour
4. Export as raw or dump
5. Modify the hosting option and server address
6. Import back and save

OPTION 3: DNS Hijacking (Easiest for testing)
--------------------------------------------
If the game uses a nameserver like ns.photonengine.io:

1. Find your hosts file:
   - Linux: /etc/hosts
   - Windows: C:\\Windows\\System32\\drivers\\etc\\hosts

2. Add these lines:
   YOUR_SERVER_IP    ns.photonengine.io
   YOUR_SERVER_IP    ns.exitgames.com
   
3. Your Photon Server will receive connection requests

OPTION 4: Proxy Server
---------------------
Set up a transparent proxy to intercept and redirect Photon traffic:
1. Run mitmproxy or similar
2. Redirect Photon nameserver requests to your server
3. Configure your system to use the proxy

TARGET VALUES FOR PATCHING:
--------------------------
Server IP: {server_ip}
Master Port: {server_port} (UDP)
Master Port: {tcp_port} (TCP)
Hosting Mode: 2 (SelfHosted)

PHOTON SERVER SETTINGS (from assets):
------------------------------------
App ID 1: 28c108ec-052d-4900-863c-3c5aad81d945
App ID 2: f590668c-6490-4259-a9df-8dbba78093c9
""".format(server_ip=server_ip, server_port=server_port, tcp_port=4530))
    
    return True

def main():
    print("=" * 60)
    print("DRL Simulator Client Patcher")
    print("=" * 60)
    
    if len(sys.argv) > 1:
        server_ip = sys.argv[1]
    else:
        server_ip = input("Enter your server IP (default: 127.0.0.1): ").strip()
        if not server_ip:
            server_ip = "127.0.0.1"
    
    create_patched_client(server_ip)

if __name__ == "__main__":
    main()
