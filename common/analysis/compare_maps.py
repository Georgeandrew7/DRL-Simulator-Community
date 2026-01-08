#!/usr/bin/env python3
import json
import os

# Load player-state circuits
with open("DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json", "r") as f:
    ps = json.load(f)

circuits_data = json.loads(ps.get("circuits-data", "[]"))
cached_guids = set(c.get("id", "") for c in circuits_data)
print(f"Circuits in player-state: {len(cached_guids)}")

# Get map files
maps_dir = "DRL Simulator_Data/StreamingAssets/game/storage/offline/maps/"
map_files = [f.replace(".cmp", "") for f in os.listdir(maps_dir) if f.endswith(".cmp")]
print(f"Map files in offline/maps: {len(map_files)}")

# Compare
map_guids = set(map_files)
in_both = cached_guids & map_guids
in_cache_only = cached_guids - map_guids
in_maps_only = map_guids - cached_guids

print(f"In both: {len(in_both)}")
print(f"In cache only: {len(in_cache_only)}")
print(f"In maps only: {len(in_maps_only)}")

if in_maps_only:
    print(f"\nSample map files NOT in cache: {list(in_maps_only)[:5]}")
