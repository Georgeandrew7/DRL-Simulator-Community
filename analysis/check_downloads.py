#!/usr/bin/env python3
import json

# Check the original working player-state.json from Downloads
with open('/home/george/Downloads/offline/state/player/player-state.json') as f:
    state = json.load(f)

cd_str = state.get('circuits-data', '')
print(f'circuits-data length: {len(cd_str)}')
print(f'First 500 chars: {repr(cd_str[:500])}')
print()

try:
    circuits = json.loads(cd_str)
    print(f'Parsed {len(circuits)} circuits')
    for i, c in enumerate(circuits[:5]):
        maps_data = c.get('maps-data', [])
        print(f'  {i}: id={c.get("id")}, name={c.get("name")}, maps={len(maps_data)}')
        if maps_data:
            print(f'      First map: {json.dumps(maps_data[0])}')
except Exception as e:
    print(f'Parse error: {e}')
