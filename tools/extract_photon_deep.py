#!/usr/bin/env python3
"""
Deep extraction of PhotonServerSettings from DRL Simulator.
"""

import UnityPy
import os
import re

GAME_PATH = "/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data"

def find_photon_settings():
    """Find and dump PhotonServerSettings MonoBehaviour."""
    
    file_path = os.path.join(GAME_PATH, "resources.assets")
    env = UnityPy.load(file_path)
    
    for obj in env.objects:
        if obj.type.name == "MonoBehaviour":
            raw = obj.get_raw_data()
            raw_str = raw.decode('latin-1', errors='ignore')
            
            if 'PhotonServerSettings' in raw_str:
                print("=" * 60)
                print("FOUND PhotonServerSettings!")
                print("=" * 60)
                print(f"Raw data size: {len(raw)} bytes")
                print()
                
                # Dump full hex + ascii for analysis
                print("=== First 2000 bytes hex dump ===")
                for i in range(0, min(2000, len(raw)), 16):
                    chunk = raw[i:i+16]
                    hex_part = ' '.join(f'{b:02x}' for b in chunk)
                    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                    print(f"{i:04x}: {hex_part:<48} {ascii_part}")
                
                print("\n=== All printable strings ===")
                strings = re.findall(rb'[\x20-\x7e]{3,}', raw)
                for s in strings:
                    print(f"  {s.decode('latin-1')}")
                
                # Look for specific patterns
                print("\n=== Looking for IP addresses ===")
                ips = re.findall(rb'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', raw)
                for ip in ips:
                    print(f"  IP: {ip.decode()}")
                
                print("\n=== Looking for ports (4-5 digit numbers) ===")
                # Search for port-like values near "port" text
                ports = re.findall(rb'(?:port|Port|PORT).{0,10}(\d{4,5})', raw, re.IGNORECASE)
                for p in ports:
                    print(f"  Port: {p.decode()}")
                
                print("\n=== Looking for URLs ===")
                urls = re.findall(rb'https?://[^\x00]+', raw)
                for url in urls:
                    clean = url.split(b'\x00')[0]
                    print(f"  URL: {clean.decode('latin-1', errors='ignore')}")
                
                # Look for domain-like strings
                print("\n=== Looking for domains ===")
                domains = re.findall(rb'[a-zA-Z0-9\-\.]+\.(com|io|net|org|cloud|gg|games)[^\x00]{0,30}', raw)
                for d in domains:
                    print(f"  Domain: {d[0].decode('latin-1', errors='ignore') if isinstance(d, tuple) else d.decode('latin-1', errors='ignore')}")
                
                # Save raw data for further analysis
                with open("/home/george/.local/share/Steam/steamapps/common/DRL Simulator/photon_settings_raw.bin", "wb") as f:
                    f.write(raw)
                print("\n[Saved raw data to photon_settings_raw.bin]")
                
                return raw
    
    return None

if __name__ == "__main__":
    find_photon_settings()
