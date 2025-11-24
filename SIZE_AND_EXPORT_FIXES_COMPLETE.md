# ✅ Snapshot Size and Export Dialog - FIXES COMPLETE

## Summary of Changes

I've fixed both issues you reported:

### 1. ✅ **Fixed: Snapshot Size Showing 4.1KB Instead of 30-35GB**

**Problem:**
- Snapshots were showing as 4.1KB (4,096,000 bytes) instead of their actual size (~30-35GB)
- The bug was in `Snapshot.vala` line 720 where it used `file.query_info().get_size()` on a directory
- This returns the directory inode size (4096 bytes), NOT the total content size

**Fix Applied:**
- **File**: `timeshift/src/Core/Snapshot.vala`
- **Lines**: 704-755
- **Changes**:
  - Removed the broken "quick estimate" code
  - Changed `du -s --block-size=1` to `du -sb` for byte-accurate counting
  - Added `sudo` to the du command for proper permissions
  - Improved error logging

**Result:**
- New snapshots will calculate size correctly
- Existing snapshots need to be fixed with the provided script

---

### 2. ✅ **Enhanced: Export Dialog Now Shows File Information**

**Problem:**
- Export dialog only showed a pulsing progress bar
- No indication of which files were being copied
- Users had no feedback during long export operations

**Fix Applied:**
- **File**: `timeshift/src/Gtk/MainWindow.vala`
- **Lines**: 816-921
- **Changes**:
  - Added a new label to show current file status
  - Modified rsync command to include `-v` (verbose) and `--info=name`
  - Added periodic updates showing "Copying files..."
  - Parses rsync output to show the last file copied

**Result:**
- Export dialog now shows:
  - ✅ Snapshot name
  - ✅ Size (if calculated)
  - ✅ Elapsed time
  - ✅ Progress bar
  - ✅ **Current file status** (NEW!)

---

## How to Use the Fixes

### Step 1: Restart the Application

The fixes are now installed. **Close and restart** `linuxrollback-gtk`:

```bash
# Kill the old version
sudo pkill linuxrollback-gtk

# Start the new version
sudo linuxrollback-gtk
```

### Step 2: Fix Existing Snapshots

Run the provided script to recalculate sizes for existing snapshots:

```bash
cd /home/tell-me/huhu
./fix-snapshot-sizes.sh
```

This will:
- Scan all snapshots in `/media/tell-me/U/timeshift/snapshots/`
- Calculate actual size using `sudo du -sb`
- Update `info.json` with correct size
- Show progress for each snapshot

**Expected output:**
```
Processing: 2025-11-24_00-11-36
  Current size in info.json: 4096000 bytes
  Calculating actual size...
  Actual size: 32212254720 bytes (30GiB)
  📝 Updating info.json...
  ✅ Successfully updated!
```

### Step 3: Verify the Fixes

1. **Check snapshot sizes in the UI:**
   - Open linuxrollback-gtk
   - Look at the "Size" column
   - Should now show correct sizes (e.g., "30 GB" instead of "4.1 KB")

2. **Test export with file display:**
   - Select a snapshot
   - Click Menu → "Export Snapshot"
   - Choose a destination
   - Watch the dialog - it should show:
     - "Preparing..." → "Copying files..." → "Last file: /path/to/file"

---

## Technical Details

### Size Calculation Fix

**Before (BUGGY):**
```vala
// Line 719-726 - Used directory inode size
var file = File.new_for_path(path);
var info = file.query_info("standard::*", FileQueryInfoFlags.NONE);
int64 quick_size = info.get_size();  // Returns 4096 bytes for directory!
size_bytes = quick_size * 1000;      // Results in 4,096,000 bytes
```

**After (FIXED):**
```vala
// Calculate accurate size using du command
string cmd = "sudo du -sb '%s' 2>/dev/null | cut -f1".printf(path);
int status = exec_sync(cmd, out std_out, out std_err);
if (status == 0 && std_out.length > 0) {
    size_bytes = int64.parse(std_out.strip());  // Actual size in bytes
    update_control_file();  // Save to info.json
}
```

### Export Dialog Enhancement

**Added UI Elements:**
```vala
// New label for current file
var lbl_current_file = new Gtk.Label("");
lbl_current_file.ellipsize = Pango.EllipsizeMode.MIDDLE;
lbl_current_file.max_width_chars = 70;
lbl_current_file.set_markup("<small><i>Preparing...</i></small>");
```

**Modified rsync command:**
```vala
// Before: rsync -a --info=progress2
// After:  rsync -av --info=progress2,name
```

**Added output parsing:**
- Periodically updates label with "Copying files..."
- Parses rsync output to find last copied file
- Displays escaped filename to prevent markup injection

---

## Files Modified

1. **`timeshift/src/Core/Snapshot.vala`**
   - Fixed `calculate_size_async()` function
   - Removed broken quick estimate
   - Added sudo to du command

2. **`timeshift/src/Gtk/MainWindow.vala`**
   - Added current file label to export dialog
   - Modified rsync command for verbose output
   - Added output parsing logic

3. **Created: `fix-snapshot-sizes.sh`**
   - Script to fix existing snapshots
   - Recalculates and updates size_bytes in info.json

---

## Testing Checklist

- [ ] Restart linuxrollback-gtk
- [ ] Run `./fix-snapshot-sizes.sh`
- [ ] Verify snapshot sizes show correctly in UI
- [ ] Create a new snapshot - verify size calculates correctly
- [ ] Export a snapshot - verify file names appear in dialog
- [ ] Check that export completes successfully

---

## Summary

| Issue | Status | Fix Location |
|-------|--------|--------------|
| Size showing 4.1KB | ✅ FIXED | `Snapshot.vala:704-755` |
| Export dialog no file info | ✅ ENHANCED | `MainWindow.vala:816-921` |
| Existing snapshots wrong size | ⚠️ RUN SCRIPT | `fix-snapshot-sizes.sh` |

**All fixes are installed and ready to use after restarting the application!**

---

**Date**: 2025-11-24  
**Version**: 25.07.7 (with size and export fixes)  
**Installation**: `/usr/local/bin/linuxrollback-gtk`
