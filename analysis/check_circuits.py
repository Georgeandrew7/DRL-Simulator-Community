#!/usr/bin/env python3
import json

with open('/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json') as f:
    data = json.load(f)

cd = data.get('circuits-data', '[]')
circuits = json.loads(cd)
print(f'Cached circuits: {len(circuits)}')
if circuits:
    print(f'First: {circuits[0].get("guid")} = {circuits[0].get("map-title")}')
