#!/usr/bin/env python3
"""Test script to check if tracks have valid GUIDs"""

import sys
sys.path.insert(0, ".")

from mock_drl_backend import load_all_tracks

def main():
    print("Loading all tracks from mock_drl_backend...")
    tracks = load_all_tracks()
    
    print(f"\nTotal tracks loaded: {len(tracks)}")
    print("\n" + "="*80)
    print("FIRST 3 TRACKS - ALL FIELDS:")
    print("="*80)
    
    for i, track in enumerate(tracks[:3]):
        print(f"\n--- Track {i+1} ---")
        if isinstance(track, dict):
            for key, value in track.items():
                print(f"  {key}: {repr(value)}")
        else:
            print(f"  Track object type: {type(track)}")
            print(f"  Track content: {track}")
    
    print("\n" + "="*80)
    print("GUID ANALYSIS:")
    print("="*80)
    
    guid_empty = 0
    guid_populated = 0
    
    for track in tracks:
        if isinstance(track, dict):
            guid = track.get("guid", None)
            if guid is None or guid == "" or guid == "None":
                guid_empty += 1
            else:
                guid_populated += 1
    
    print(f"Tracks with EMPTY guid: {guid_empty}")
    print(f"Tracks with POPULATED guid: {guid_populated}")
    
    print("\nFirst 5 track GUIDs:")
    for i, track in enumerate(tracks[:5]):
        if isinstance(track, dict):
            guid = track.get("guid", "NO GUID FIELD")
            name = track.get("name", "NO NAME")
            print(f"  [{i+1}] name={repr(name)}, guid={repr(guid)}")

if __name__ == "__main__":
    main()
