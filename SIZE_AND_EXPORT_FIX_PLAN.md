# Snapshot Size Display Bug - Analysis and Fix

## Problem 1: Size Showing 4.1KB Instead of 30-35GB

### Root Cause:
The `calculate_size_async()` function in `Snapshot.vala` (lines 704-755) has a bug in the "quick estimate" calculation:

```vala
// Line 719-726 - BUGGY CODE
var file = File.new_for_path(path);
var info = file.query_info("standard::*", FileQueryInfoFlags.NONE);
int64 quick_size = info.get_size();  // ← This only gets directory inode size (4096 bytes)!

if (quick_size > 0) {
    size_bytes = quick_size * 1000; // Rough estimate
    // Results in: 4096 * 1000 = 4,096,000 bytes = 4.1 MB (displayed as 4.1 KB due to rounding)
}
```

**What's Wrong:**
- `file.query_info().get_size()` on a **directory** returns the inode size (~4096 bytes), NOT the total size of all files inside
- This gets multiplied by 1000 to give 4,096,000 bytes
- This wrong value gets saved to `info.json` as `"size_bytes": "4096000"`
- The background thread that calculates the accurate size (line 732-754) runs with `sudo` but the result isn't being displayed properly

### The Fix:

**Option 1: Remove the broken quick estimate** (Recommended)
```vala
public void calculate_size_async() {
    if (btrfs_mode) {
        return;
    }
    
    if (size_bytes > 0) {
        return; // Already calculated
    }
    
    // Calculate accurate size in background (no broken quick estimate)
    new Thread<void*>.try("calc-size-%s".printf(name), () => {
        string cmd = "sudo du -sb '%s' 2>/dev/null | cut -f1".printf(path);
        string std_out, std_err;
        int status = exec_sync(cmd, out std_out, out std_err);
        
        if (status == 0 && std_out.length > 0) {
            int64 accurate_size = int64.parse(std_out.strip());
            if (accurate_size > 0) {
                size_bytes = accurate_size;
                update_control_file();
                log_debug("Calculated size for %s: %s".printf(name, format_file_size(size_bytes)));
            }
        }
        
        return null;
    });
}
```

**Option 2: Fix existing snapshots**
Run this command to recalculate sizes for all existing snapshots:
```bash
for snapshot in /media/tell-me/U/timeshift/snapshots/*; do
    if [ -d "$snapshot" ]; then
        size=$(sudo du -sb "$snapshot" 2>/dev/null | cut -f1)
        if [ -n "$size" ]; then
            # Update info.json with correct size
            sudo sed -i "s/\"size_bytes\" : \"[0-9]*\"/\"size_bytes\" : \"$size\"/" "$snapshot/info.json"
            echo "Updated $snapshot: $size bytes"
        fi
    fi
done
```

---

## Problem 2: Export Dialog Should Show Files Being Transferred

### Current State:
The export dialog (lines 784-933 in MainWindow.vala) shows:
- ✅ Snapshot name
- ✅ Size (if available)
- ✅ Elapsed time
- ✅ Progress bar (pulsing)
- ❌ **NO file names being copied**

### The Fix:

We need to:
1. Parse rsync output in real-time
2. Extract the current file being copied
3. Update a label in the dialog

**Modified export_snapshot() function:**

```vala
// Add after line 821 (after progress bar):
var lbl_current_file = new Gtk.Label("");
lbl_current_file.xalign = 0;
lbl_current_file.margin = 6;
lbl_current_file.ellipsize = Pango.EllipsizeMode.MIDDLE;
lbl_current_file.max_width_chars = 60;
content.add(lbl_current_file);

// Change the rsync command to include verbose output (line 866):
string cmd = "pkexec rsync -av --info=progress2,name '%s/' '%s/'".printf(source_path, dest_path);

// Then modify the thread to parse output in real-time:
new Thread<void*>("export-snapshot", () => {
    try {
        string[] argv = {"/bin/sh", "-c", cmd};
        string[] env = Environ.get();
        Pid child_pid;
        int standard_output;
        int standard_error;
        
        Process.spawn_async_with_pipes(
            null, argv, env,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null,
            out child_pid,
            null,
            out standard_output,
            out standard_error
        );
        
        // Read output in real-time
        var channel = new IOChannel.unix_new(standard_output);
        string line;
        size_t length;
        
        while (channel.read_line(out line, out length, null) == IOStatus.NORMAL) {
            if (export_cancelled) break;
            
            line = line.strip();
            if (line.length > 0 && !line.has_prefix("sending") && !line.has_prefix("total")) {
                // Update current file label
                Idle.add(() => {
                    lbl_current_file.label = "Copying: " + line;
                    return false;
                });
            }
        }
        
        int status;
        Process.close_pid(child_pid);
        
        Idle.add(() => {
            export_complete = true;
            Source.remove(timeout_id);
            progress_dialog.destroy();
            
            if (!export_cancelled) {
                gtk_messagebox(
                    _("Export Complete"),
                    _("Snapshot exported successfully to:\n%s").printf(dest_path),
                    this, false
                );
            }
            return false;
        });
        
    } catch (Error e) {
        log_error(e.message);
    }
    
    return null;
});
```

---

## Summary of Changes Needed:

### File: `timeshift/src/Core/Snapshot.vala`
1. **Lines 717-729**: Remove broken quick estimate code
2. **Line 734**: Change `du -s` to `du -sb` for byte-accurate size
3. **Line 734**: Add `sudo` to the du command

### File: `timeshift/src/Gtk/MainWindow.vala`
1. **After line 821**: Add label for current file being copied
2. **Line 866**: Change rsync command to include `-v` and `--info=name`
3. **Lines 868-915**: Replace simple exec_sync with real-time output parsing

---

## Testing:

1. **Test size calculation:**
   ```bash
   # Check a snapshot's actual size
   sudo du -sb /media/tell-me/U/timeshift/snapshots/2025-11-24_00-11-36
   
   # Should show ~30-35GB, not 4MB
   ```

2. **Test export with file display:**
   - Create a test snapshot
   - Export it to `/tmp/test-export`
   - Verify the dialog shows filenames being copied
   - Verify the size is correct

---

## Priority:

1. **HIGH**: Fix size calculation (affects all snapshots)
2. **MEDIUM**: Add file display to export dialog (UX improvement)
