# LinuxRollback Snapshot Size Display & Export Feature

## Implementation Plan

### Issue 1: Snapshot Sizes Not Showing

**Problem**: 
- Size column only visible when `App.btrfs_qgroups_enabled` is true
- RSYNC snapshots show empty size (line 443 in SnapshotListBox.vala)
- No size property in Snapshot class for RSYNC mode

**Solution**:
1. Add `size_bytes` property to Snapshot class
2. Calculate size using `du -sb` command for RSYNC snapshots
3. Cache size in info.json to avoid recalculation
4. Update cell_size_render() to show size for both BTRFS and RSYNC
5. Make size column always visible

### Issue 2: Export Snapshot Feature

**Problem**:
- No way to copy snapshots to external devices
- Users need to manually copy snapshot directories

**Solution**:
1. Add "Export Snapshot" menu item in context menu
2. Create ExportSnapshotWindow dialog
3. Allow user to select destination (external drive)
4. Use rsync to copy snapshot with progress
5. Verify exported snapshot integrity

## Implementation Steps

### Step 1: Add Size Calculation to Snapshot Class

```vala
// In Snapshot.vala
public int64 size_bytes = 0;  // Add property

// Add method to calculate size
public void calculate_size() {
    if (btrfs_mode) {
        // Already calculated in subvolumes
        return;
    }
    
    // For RSYNC, use du command
    string cmd = "du -sb '%s'".printf(path);
    string std_out, std_err;
    exec_sync(cmd, out std_out, out std_err);
    
    if (std_out.length > 0) {
        string[] parts = std_out.split("\t");
        if (parts.length > 0) {
            size_bytes = int64.parse(parts[0]);
        }
    }
}
```

### Step 2: Update SnapshotListBox to Show Sizes

```vala
// In cell_size_render()
if (bak.btrfs_mode) {
    // existing BTRFS code
} else {
    // NEW: Show RSYNC size
    if (bak.size_bytes > 0) {
        ctxt.text = format_file_size(bak.size_bytes);
    } else {
        ctxt.text = _("Calculating...");
    }
}

// Make column always visible
col_size.visible = true;  // Remove btrfs_qgroups_enabled check
```

### Step 3: Add Export Menu Item

```vala
// In init_list_view_context_menu()
var item = new ImageMenuItem.with_label(_("Export Snapshot..."));
item.image = IconManager.lookup_image("document-save", 16);
item.activate.connect(() => { export_selected(); });
menu_snapshots.append(item);
mi_export = item;
```

### Step 4: Create Export Dialog

Create new file: `src/Gtk/ExportSnapshotWindow.vala`

```vala
class ExportSnapshotWindow : Gtk.Dialog {
    private Gtk.FileChooserButton file_chooser;
    private Gtk.ProgressBar progress_bar;
    private Snapshot snapshot;
    
    public ExportSnapshotWindow(Snapshot snap, Gtk.Window parent) {
        snapshot = snap;
        set_transient_for(parent);
        set_modal(true);
        title = _("Export Snapshot");
        
        // Add file chooser for destination
        file_chooser = new Gtk.FileChooserButton(
            _("Select Destination"),
            Gtk.FileChooserAction.SELECT_FOLDER
        );
        
        // Add progress bar
        progress_bar = new Gtk.ProgressBar();
        
        // Add buttons
        add_button(_("Cancel"), Gtk.ResponseType.CANCEL);
        add_button(_("Export"), Gtk.ResponseType.OK);
    }
    
    private void export_snapshot() {
        string dest = file_chooser.get_filename();
        string dest_path = Path.build_filename(dest, snapshot.name);
        
        // Use rsync to copy
        string cmd = "rsync -av --info=progress2 '%s/' '%s/'".printf(
            snapshot.path, dest_path
        );
        
        // Execute with progress updates
        // ...
    }
}
```

## Files to Modify

1. `src/Core/Snapshot.vala` - Add size property and calculation
2. `src/Gtk/SnapshotListBox.vala` - Update size display and add export menu
3. `src/Gtk/MainWindow.vala` - Add export_selected signal handler
4. `src/Gtk/ExportSnapshotWindow.vala` - NEW FILE for export dialog

## Benefits

1. ✅ Users can see snapshot sizes for both BTRFS and RSYNC
2. ✅ Easy comparison of snapshot sizes
3. ✅ Export snapshots to external drives for backup
4. ✅ Progress indication during export
5. ✅ Verify exported snapshots
