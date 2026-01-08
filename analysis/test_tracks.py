#!/usr/bin/env python3
import json, os

MAPS_DIR = "/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data/StreamingAssets/game/content/maps"
tracks = []

for d in os.listdir(MAPS_DIR):
    p = os.path.join(MAPS_DIR, d)
    if os.path.isdir(p):
        for f in os.listdir(p):
            if f.endswith('.json'):
                try:
                    with open(os.path.join(p,f)) as fp:
                        data = json.load(fp)
                    if 'data' in data and isinstance(data['data'], dict) and 'data' in data['data']:
                        for t in data['data']['data']:
                            if 'guid' in t:
                                tracks.append({'guid': t['guid'], 'title': t.get('map-title','')})
                except Exception as e:
                    print(f"Error: {e}")

print(f"Found {len(tracks)} tracks")
if tracks:
    for t in tracks[:5]:
        print(f"  {t['guid']} = {t['title']}")
