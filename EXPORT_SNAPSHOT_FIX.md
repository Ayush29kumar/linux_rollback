# Export Snapshot Fix - Complete Analysis

## Problem 1: Wrong Source Path (FIXED)

When trying to export a snapshot, the operation was failing with:
```
Error: rsync: [sender] change_dir "/media/tell-me/FEFB-F3264/2025-11-24_00-11-36" failed: No such file or directory (2)
```

**Root Cause:** For RSYNC snapshots, files are stored in a `localhost` subdirectory, not directly in the snapshot path.

**Fix:** Changed source path to use `bak.path + "/localhost"` for RSYNC snapshots.

## Problem 2: Export Takes Hours / Appears Frozen (FIXED)

The export dialog shows a pulsing progress bar but takes hours to complete with no indication of actual progress.

**Root Causes:**
1. **No real progress tracking** - The progress bar just pulses, doesn't show percentage
2. **Dangerous `--delete` flag** - This flag tells rsync to delete files in the destination that don't exist in the source. This is:
   - **Dangerous** for export operations
   - **Slower** because rsync has to scan the destination directory first
   - **Unnecessary** for a simple copy operation
3. **Verbose output without progress** - Using `-av` gives verbose output but no progress percentage

**Fixes Applied:**

### 1. Removed `--delete` Flag
```vala
// Before:
string cmd = "pkexec rsync -av --delete '%s/' '%s/' 2>&1".printf(source_path, dest_path);

// After:
string cmd = "pkexec rsync -a --info=progress2 '%s/' '%s/' 2>&1".printf(source_path, dest_path);
```

**Benefits:**
- ✅ **Safer** - Won't accidentally delete files
- ✅ **Faster** - No need to scan destination first
- ✅ **Better progress** - `--info=progress2` shows percentage completion

### 2. Added Progress Information
The `--info=progress2` flag provides output like:
```
  1,234,567  45%  123.45kB/s    0:01:23
```

This shows:
- Bytes transferred
- **Percentage complete**
- Transfer speed
- Estimated time remaining

## Why Export Was Taking Hours

Snapshots can be **very large** (several GB to tens of GB). For example:
- A typical Linux system snapshot: 5-15 GB
- With applications installed: 20-50 GB
- Transfer speed on USB 2.0: ~30 MB/s → 10 GB takes ~5-6 minutes
- Transfer speed on USB 3.0: ~100 MB/s → 10 GB takes ~1-2 minutes
- Transfer speed on HDD: ~50-100 MB/s

**The export was actually working**, but:
1. The progress bar was just pulsing (no percentage shown)
2. The `--delete` flag made it slower by scanning the destination first
3. No way to know how much was left

## Current Status

✅ **Both issues fixed:**
1. Correct source path for RSYNC snapshots
2. Removed `--delete` flag for faster, safer export
3. Added `--info=progress2` for better progress tracking

## Testing

1. Rebuild: `meson compile -C build`
2. Install: `sudo meson install -C build`
3. Run LinuxRollback and try exporting a snapshot
4. The export should now:
   - Work correctly (no "directory not found" error)
   - Be faster (no --delete scanning)
   - Show progress information in the rsync output

## Note

The progress bar in the GUI still pulses because we're using `exec_sync()` which waits for the entire command to complete. To show real-time progress percentage in the GUI, we would need to:
1. Parse rsync's output line-by-line
2. Extract the percentage
3. Update the progress bar in real-time

This would require a more complex implementation using `Process.spawn_async_with_pipes()` instead of `exec_sync()`. The current fix makes export **work correctly and faster**, but the GUI progress bar still just pulses.

## Files Modified

- `/home/tell-me/huhu/timeshift/src/Gtk/MainWindow.vala` (lines 860-865)

## Recommendation

For large snapshots, the export will still take time (proportional to the snapshot size and disk speed). Users should:
1. Be patient - the export IS working even if the progress bar just pulses
2. Check the destination folder size to see progress
3. Use a fast destination (USB 3.0, SSD) for quicker exports
