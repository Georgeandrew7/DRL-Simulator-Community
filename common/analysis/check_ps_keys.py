#!/usr/bin/env python3
import json

with open("DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json", "r") as f:
    ps = json.load(f)
    
# Look for all keys that might contain circuits
for key in ps.keys():
    if "circuit" in key.lower() or "map" in key.lower() or "track" in key.lower():
        print(f"Key: {key}")
        val = ps[key]
        if isinstance(val, str) and len(val) > 0:
            try:
                parsed = json.loads(val)
                if isinstance(parsed, list):
                    print(f"  -> List with {len(parsed)} items")
                    if len(parsed) > 0:
                        print(f"  -> First item keys: {list(parsed[0].keys()) if isinstance(parsed[0], dict) else parsed[0]}")
                else:
                    print(f"  -> Type: {type(parsed)}, preview: {str(parsed)[:100]}")
            except:
                print(f"  -> String of length {len(val)}: {val[:100]}...")
        else:
            print(f"  -> {type(val)}: {str(val)[:100]}")

# Also check what circuits-data contains
print("\n--- circuits-data raw content ---")
cd = ps.get("circuits-data", "")
print(f"circuits-data length: {len(cd)}")
print(f"circuits-data content: {cd[:500]}")
