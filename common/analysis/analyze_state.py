#!/usr/bin/env python3
import json

with open('DRL Simulator_Data/StreamingAssets/game/storage/offline/state/player/player-state.json') as f:
    d = json.load(f)

print('=== TOP-LEVEL KEYS ===')
for k in sorted(d.keys()):
    v = d[k]
    if isinstance(v, list):
        print(f'  {k}: list[{len(v)}]')
    elif isinstance(v, dict):
        print(f'  {k}: dict[{len(v)} keys]')
    else:
        print(f'  {k}: {type(v).__name__}')

print('\n=== CIRCUITS-DATA ANALYSIS ===')
if 'circuits-data' in d:
    cd = d['circuits-data']
    if isinstance(cd, list):
        print(f'  circuits-data is a list with {len(cd)} items')
        if cd:
            print(f'  First item keys: {list(cd[0].keys()) if isinstance(cd[0], dict) else type(cd[0])}')
    elif isinstance(cd, dict):
        print(f'  circuits-data is a dict with keys: {list(cd.keys())}')
else:
    print('  circuits-data key not found')

print('\n=== MAP/TRACK RELATED KEYS ===')
map_related = ['map', 'maps', 'track', 'tracks', 'circuit', 'circuits', 'level', 'levels']
for k in d.keys():
    for term in map_related:
        if term in k.lower():
            v = d[k]
            if isinstance(v, list):
                print(f'  {k}: list[{len(v)}]')
                if v and isinstance(v[0], dict):
                    print(f'    Sample keys: {list(v[0].keys())[:10]}')
            elif isinstance(v, dict):
                print(f'  {k}: dict with keys {list(v.keys())[:5]}...')
            else:
                print(f'  {k}: {repr(v)[:60]}')
            break
