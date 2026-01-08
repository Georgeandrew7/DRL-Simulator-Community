#!/usr/bin/env python3
"""
DRL Simulator Binary Patcher

This script patches resources.assets to change the HostingOption 
from PhotonCloud (1) to SelfHosted (2).

MAKE SURE TO BACKUP YOUR FILES!
"""

import os
import sys
import shutil

GAME_PATH = "/home/george/.local/share/Steam/steamapps/common/DRL Simulator/DRL Simulator_Data"
RESOURCES_FILE = os.path.join(GAME_PATH, "resources.assets")

def find_photon_settings_offset(data):
    """Find the PhotonServerSettings MonoBehaviour in the asset file."""
    
    # Search for the second GUID which ends right before HostingOption
    # f590668c-6490-4259-a9df-8dbba78093c9
    search_pattern = b"f590668c-6490-4259-a9df-8dbba78093c9"
    
    offset = data.find(search_pattern)
    if offset == -1:
        print("Could not find GUID pattern")
        return None
    
    # The HostingOption is immediately after this GUID string
    # GUID is 36 bytes, so HostingOption starts at offset + 36
    hosting_offset = offset + 36
    
    return hosting_offset

def patch_hosting_option(dry_run=True):
    """
    Patch the HostingOption from PhotonCloud (1) to SelfHosted (2).
    
    Based on our analysis of resources.assets:
    - GUID "f590668c-6490-4259-a9df-8dbba78093c9" is at offset 0x42b620
    - Immediately after (offset 0x42b640) is HostingOption
    - Current value: 01 00 00 00 (little-endian 1 = PhotonCloud)
    - Target value:  02 00 00 00 (little-endian 2 = SelfHosted)
    """
    
    backup_file = RESOURCES_FILE + ".original"
    
    print("=" * 60)
    print("DRL Simulator Binary Patcher")
    print("=" * 60)
    print(f"Target file: {RESOURCES_FILE}")
    print(f"Mode: {'DRY RUN (no changes)' if dry_run else 'LIVE PATCHING'}")
    print()
    
    # Read the file
    with open(RESOURCES_FILE, 'rb') as f:
        data = bytearray(f.read())
    
    print(f"File size: {len(data):,} bytes")
    
    # Find the HostingOption offset
    hosting_option_offset = find_photon_settings_offset(data)
    
    if hosting_option_offset is None:
        print("ERROR: Could not find PhotonServerSettings in the file!")
        return False
    
    print(f"Found HostingOption at file offset: 0x{hosting_option_offset:08X}")
    
    # Read current value
    current_value = int.from_bytes(data[hosting_option_offset:hosting_option_offset+4], 'little')
    
    hosting_names = {
        0: "NotSet",
        1: "PhotonCloud",
        2: "SelfHosted",
        3: "OfflineMode"
    }
    
    print(f"Current value: {current_value} ({hosting_names.get(current_value, 'Unknown')})")
    
    # Show context
    context_before = data[hosting_option_offset-8:hosting_option_offset]
    context_after = data[hosting_option_offset+4:hosting_option_offset+12]
    
    print(f"Context before (8 bytes): {context_before.hex()}")
    print(f"  -> Should end with: 39 63 39 (end of '9c9')")
    print(f"Context after (8 bytes): {context_after.hex()}")
    print(f"  -> Should be: 01 00 00 00 ff ff ff ff")
    
    # Verify context
    if context_before[-3:] == b'9c9' or context_before.endswith(b'c9'):
        print("✓ Context verification: PASSED")
    else:
        print("⚠ Context verification: UNCERTAIN")
    
    if current_value not in [0, 1, 2, 3]:
        print(f"\n⚠ Unexpected value {current_value}. Expected 0-3.")
        print("  The file structure may be different. Aborting.")
        return False
    
    if current_value == 2:
        print("\n✓ HostingOption is already set to SelfHosted!")
        return True
    
    # Patch to SelfHosted (2)
    new_value = 2
    
    print(f"\nWill change: {current_value} ({hosting_names[current_value]}) -> {new_value} ({hosting_names[new_value]})")
    
    if dry_run:
        print("\n[DRY RUN] No changes made. Run with --patch to apply.")
        return True
    
    # Create backup
    if not os.path.exists(backup_file):
        print(f"\nCreating backup: {backup_file}")
        shutil.copy2(RESOURCES_FILE, backup_file)
    else:
        print(f"\nBackup already exists: {backup_file}")
    
    # Apply patch
    data[hosting_option_offset:hosting_option_offset+4] = new_value.to_bytes(4, 'little')
    
    # Write patched file
    with open(RESOURCES_FILE, 'wb') as f:
        f.write(data)
    
    print("✓ Patch applied successfully!")
    print("\nNext steps:")
    print("1. Start your Photon Server (run setup-server.sh)")
    print("2. Launch the game")
    print("3. The game should connect to your local server")
    print("\nTo restore original: copy resources.assets.original back")
    
    return True

def restore_backup():
    """Restore the original resources.assets file."""
    backup_file = RESOURCES_FILE + ".original"
    
    if not os.path.exists(backup_file):
        print("No backup file found!")
        return False
    
    print(f"Restoring from: {backup_file}")
    shutil.copy2(backup_file, RESOURCES_FILE)
    print("✓ Restored successfully!")
    return True

def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--patch":
            patch_hosting_option(dry_run=False)
        elif sys.argv[1] == "--restore":
            restore_backup()
        elif sys.argv[1] == "--help":
            print("Usage:")
            print("  python binary_patcher.py          # Dry run (show what would change)")
            print("  python binary_patcher.py --patch  # Apply patch")
            print("  python binary_patcher.py --restore # Restore backup")
        else:
            print(f"Unknown option: {sys.argv[1]}")
            print("Use --help for usage information")
    else:
        patch_hosting_option(dry_run=True)

if __name__ == "__main__":
    main()
