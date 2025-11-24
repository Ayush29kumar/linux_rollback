#!/bin/bash
# Script to fix size_bytes in existing snapshot info.json files

echo "=== Fixing Snapshot Sizes ==="
echo "This script will recalculate and update the size for all existing snapshots"
echo ""

SNAPSHOT_DIR="/media/tell-me/U/timeshift/snapshots"

if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "Error: Snapshot directory not found: $SNAPSHOT_DIR"
    exit 1
fi

count=0
fixed=0

for snapshot in "$SNAPSHOT_DIR"/*; do
    if [ -d "$snapshot" ]; then
        name=$(basename "$snapshot")
        info_file="$snapshot/info.json"
        
        if [ ! -f "$info_file" ]; then
            echo "⚠ Skipping $name - no info.json found"
            continue
        fi
        
        count=$((count + 1))
        
        # Get current size from info.json
        current_size=$(grep -oP '"size_bytes"\s*:\s*"\K[0-9]+' "$info_file")
        
        echo "Processing: $name"
        echo "  Current size in info.json: $current_size bytes"
        
        # Calculate actual size
        echo "  Calculating actual size (this may take a moment)..."
        actual_size=$(sudo du -sb "$snapshot" 2>/dev/null | cut -f1)
        
        if [ -z "$actual_size" ]; then
            echo "  ❌ Failed to calculate size"
            continue
        fi
        
        echo "  Actual size: $actual_size bytes ($(numfmt --to=iec-i --suffix=B $actual_size))"
        
        # Update if different
        if [ "$current_size" != "$actual_size" ]; then
            echo "  📝 Updating info.json..."
            sudo sed -i "s/\"size_bytes\" : \"[0-9]*\"/\"size_bytes\" : \"$actual_size\"/" "$info_file"
            
            # Verify the update
            new_size=$(grep -oP '"size_bytes"\s*:\s*"\K[0-9]+' "$info_file")
            if [ "$new_size" = "$actual_size" ]; then
                echo "  ✅ Successfully updated!"
                fixed=$((fixed + 1))
            else
                echo "  ❌ Update failed - verification mismatch"
            fi
        else
            echo "  ✓ Size is already correct"
        fi
        
        echo ""
    fi
done

echo "=== Summary ==="
echo "Total snapshots processed: $count"
echo "Snapshots fixed: $fixed"
echo ""
echo "Done! Restart linuxrollback-gtk to see the updated sizes."
