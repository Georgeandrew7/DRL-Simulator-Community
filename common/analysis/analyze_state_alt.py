#!/usr/bin/env python3
import json
import sys

# Check the game's current state
game_state_path = '/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json'

with open(game_state_path) as f:
    state = json.load(f)

cd_str = state.get('circuits-data', '')
print(f'circuits-data length: {len(cd_str)}')

# Check what format it is
if cd_str.startswith('[{'):
    print('Format: JSON array')
    circuits = json.loads(cd_str)
    print(f'  Number of items: {len(circuits)}')
    if circuits:
        first = circuits[0]
        print(f'  First item keys: {list(first.keys())}')
        if 'id' in first:
            print(f'  First item id: {first.get("id")}')
        if 'name' in first:
            print(f'  First item name: {first.get("name")}')
        if 'guid' in first:
            print(f'  First item guid: {first.get("guid")}')
        if 'map-title' in first:
            print(f'  First item map-title: {first.get("map-title")}')
elif cd_str.startswith('{'):
    print('Format: JSON object')
else:
    print(f'Format: Unknown, starts with: {repr(cd_str[:50])}')

print()
print('Full first 1000 chars of circuits-data:')
print(cd_str[:1000])
