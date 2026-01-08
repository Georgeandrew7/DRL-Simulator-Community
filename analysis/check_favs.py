#!/usr/bin/env python3
import json

state_path = '/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json'
with open(state_path) as f:
    state = json.load(f)

# Check circuits-data structure (this controls the tabs!)
print('=== circuits-data ===')
cd_str = state.get('circuits-data', '')
print(f'Type: {type(cd_str)}')
print(f'Length: {len(cd_str)}')
try:
    circuits = json.loads(cd_str)
    print(f'Parsed {len(circuits)} circuit playlists')
    for i, circuit in enumerate(circuits):
        maps_data = circuit.get('maps-data', [])
        print(f'  {i}: id={circuit.get("id")}, name={circuit.get("name")}, maps={len(maps_data)}')
        if maps_data:
            print(f'      First map: {json.dumps(maps_data[0])}')
except Exception as e:
    print(f'Parse error: {e}')

print()
print('=== maps-favorite ===')
fav_str = state.get('maps-favorite', '')
print(f'Type: {type(fav_str)}')
print(f'Length: {len(fav_str)}')
try:
    favs = json.loads(fav_str)
    print(f'Parsed {len(favs)} favorites')
    print('First 5 favorites:')
    for i, fav in enumerate(favs[:5]):
        print(f'  {i}: {json.dumps(fav)}')
except Exception as e:
    print(f'Parse error: {e}')
