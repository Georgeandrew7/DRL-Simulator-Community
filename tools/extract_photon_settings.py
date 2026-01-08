#!/usr/bin/env python3
"""
Extract PhotonServerSettings and other networking configuration from DRL Simulator Unity assets.
"""

import UnityPy
import os
import json

GAME_PATH = "/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data"

def extract_photon_settings():
    """Search for PhotonServerSettings and similar networking assets."""
    
    # Files to check
    files_to_check = [
        os.path.join(GAME_PATH, "resources.assets"),
        os.path.join(GAME_PATH, "globalgamemanagers"),
        os.path.join(GAME_PATH, "globalgamemanagers.assets"),
    ]
    
    # Also add sharedassets
    for i in range(10):
        path = os.path.join(GAME_PATH, f"sharedassets{i}.assets")
        if os.path.exists(path):
            files_to_check.append(path)
    
    results = []
    
    for file_path in files_to_check:
        if not os.path.exists(file_path):
            continue
            
        print(f"\n=== Scanning: {os.path.basename(file_path)} ===")
        
        try:
            env = UnityPy.load(file_path)
            
            for obj in env.objects:
                try:
                    # Check for MonoBehaviour objects (which could be PhotonServerSettings)
                    if obj.type.name == "MonoBehaviour":
                        # Get raw bytes and search for "photon"
                        raw = obj.get_raw_data()
                        raw_str = raw.decode('latin-1', errors='ignore')
                        
                        if 'photon' in raw_str.lower() or 'appid' in raw_str.lower():
                            print(f"\n[FOUND] MonoBehaviour with Photon/AppId reference")
                            # Extract printable strings from raw data
                            import re
                            strings = re.findall(rb'[\x20-\x7e]{4,}', raw)
                            for s in strings[:20]:
                                decoded = s.decode('latin-1')
                                if any(x in decoded.lower() for x in ['photon', 'app', 'server', 'host', 'region', 'master']):
                                    print(f"  String: {decoded}")
                            
                            results.append({
                                "type": "MonoBehaviour",
                                "raw_strings": [s.decode('latin-1') for s in strings[:50]]
                            })
                    
                    # Also check for TextAsset which might contain config
                    elif obj.type.name == "TextAsset":
                        data = obj.read()
                        name = getattr(data, 'm_Name', '')
                        
                        if "photon" in name.lower() or "server" in name.lower() or "network" in name.lower():
                            print(f"\n[FOUND] TextAsset: {name}")
                            text = getattr(data, 'm_Script', b'')
                            if isinstance(text, bytes):
                                text = text.decode('utf-8', errors='ignore')
                            print(f"  Content (first 500 chars): {text[:500]}")
                            results.append({"type": "TextAsset", "name": name, "content": text})
                            
                except Exception as e:
                    print(f"  Error: {e}")
                    
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
    
    return results

def search_serialized_files():
    """Search for specific serialized configuration."""
    print("\n\n=== Searching for serialized Photon configuration ===")
    
    try:
        env = UnityPy.load(os.path.join(GAME_PATH, "resources.assets"))
        
        print(f"Found {len(list(env.objects))} objects in resources.assets")
        
        # Get type summary
        types = {}
        for obj in env.objects:
            t = obj.type.name
            types[t] = types.get(t, 0) + 1
        
        print("\nObject types found:")
        for t, count in sorted(types.items(), key=lambda x: -x[1])[:20]:
            print(f"  {t}: {count}")
            
        # Look specifically at all MonoBehaviours
        print("\n=== All MonoBehaviour scripts ===")
        for obj in env.objects:
            if obj.type.name == "MonoBehaviour":
                try:
                    data = obj.read()
                    if hasattr(data, 'm_Script') and data.m_Script:
                        try:
                            script = data.m_Script.read()
                            if hasattr(script, 'm_ClassName'):
                                name = script.m_ClassName
                                if any(x in name.lower() for x in ['photon', 'network', 'server', 'connect', 'multiplayer', 'online']):
                                    print(f"  - {name}")
                        except:
                            pass
                except:
                    pass
                    
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    print("DRL Simulator - Photon Settings Extractor")
    print("=" * 50)
    
    results = extract_photon_settings()
    search_serialized_files()
    
    print("\n\n=== Summary ===")
    print(f"Found {len(results)} Photon-related assets")
