# Critical Bug Analysis: Disk Space Issue

## 🚨 Problem Summary

Your hard drive ran out of space (100% full) because the LinuxRollback application created a **35GB snapshot in the wrong location** due to a shell redirection bug.

## 📍 Root Cause

**File**: `timeshift/src/Gtk/MainWindow.vala`  
**Line**: 865  
**Function**: `export_snapshot()`

### The Bug

```vala
string cmd = "pkexec rsync -a --info=progress2 '%s/' '%s/' 2>&1".printf(source_path, dest_path);
```

The command includes `2>&1` (shell redirection operator) at the end, but when this command is executed via `exec_sync()` on line 874:

```vala
status = exec_sync(cmd, out std_out, out std_err);
```

The `exec_sync()` function uses `Process.spawn_command_line_sync()` which **does NOT execute commands through a shell**. This means:
- Shell operators like `2>&1`, `|`, `>`, `<` are treated as **literal arguments**
- The `2>&1` was interpreted as a **directory name** instead of a redirection operator
- rsync created a directory literally named `/home/tell-me/2>&1` and copied 35GB of data into it

## 🔍 What Was Created

```
/home/tell-me/2>&1/
├── localhost/          # 35GB - Full system snapshot
│   ├── usr/           # 19GB
│   ├── var/           # 9.3GB
│   ├── swap.img       # 4.1GB
│   ├── opt/           # 2.2GB
│   └── boot/          # 229MB
├── rsync-log          # 31MB
├── info.json          # Snapshot metadata
└── exclude.list       # Exclusion rules
```

## ✅ Solution Applied

**Deleted the incorrectly placed snapshot:**
```bash
sudo rm -rf "/home/tell-me/2>&1"
```

**Result:**
- Freed: **35GB** of disk space
- Disk usage: Reduced from **100%** to **88%**
- Available space: **28GB**

## 🔧 Recommended Fix

The `2>&1` redirection is unnecessary because `exec_sync()` already captures both stdout and stderr separately. Remove it from the command:

### Before (Line 865):
```vala
string cmd = "pkexec rsync -a --info=progress2 '%s/' '%s/' 2>&1".printf(source_path, dest_path);
```

### After:
```vala
string cmd = "pkexec rsync -a --info=progress2 '%s/' '%s/'".printf(source_path, dest_path);
```

## 📝 Technical Details

### Why `2>&1` Doesn't Work Here

1. **`exec_sync()` implementation** (`Utility/TeeJee.Process.vala:67-82`):
   ```vala
   public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){
       try {
           int status;
           Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
           return status;
       }
       catch (Error e){
           log_error (e.message);
           return -1;
       }
   }
   ```

2. **`Process.spawn_command_line_sync()`** is a GLib function that:
   - Parses the command string into arguments
   - Does NOT invoke a shell (`/bin/sh`)
   - Treats special characters as literal strings
   - Already separates stdout and stderr into different output parameters

3. **For shell features**, you should use `exec_script_sync()` instead, which:
   - Creates a temporary bash script
   - Executes it through `/bin/bash`
   - Supports pipes, redirections, and other shell features

## 🎯 Prevention

To prevent similar issues:

1. **Never use shell operators** (`2>&1`, `|`, `>`, etc.) with `exec_sync()`
2. **Use `exec_script_sync()`** if you need shell features
3. **Or simply remove unnecessary redirections** since the function already captures both streams

## 📊 Impact

- **Severity**: Critical (caused disk full condition)
- **Data Loss**: None (snapshot was successfully deleted)
- **User Impact**: System became unusable due to no free space
- **Fix Complexity**: Simple (remove 5 characters from line 865)

## 🔍 How to Verify the Fix

After applying the fix, test the export functionality:
1. Create a test snapshot
2. Export it to a safe location
3. Verify no `2>&1` directory is created
4. Confirm the export completes successfully
