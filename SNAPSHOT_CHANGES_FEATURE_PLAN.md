# LinuxRollback Snapshot Changes/Diff Feature - Implementation Plan

## Feature Request

Add a **"Changes"** column and **"View Changes Details"** dialog that shows:
1. What files/packages changed between snapshots
2. Summary of major changes (files added/deleted/modified)
3. How to revert specific changes
4. Detailed diff view

## Current Infrastructure (Already Available)

### ✅ Existing Components:

1. **Rsync Log Files** (already created during snapshot):
   - `rsync-log` - Full rsync output
   - `rsync-log-changes` - Parsed changes only
   - Contains: files created, deleted, modified

2. **RsyncTask.parse_log()** - Already parses rsync logs:
   - Returns `ArrayList<FileItem>`
   - Each FileItem has: path, file_type, file_status, size

3. **FileItem Class** - Represents changed files:
   - `file_path` - Full path
   - `file_type` - File, directory, link
   - `file_status` - Created, deleted, modified, unchanged
   - `file_size` - Size in bytes

4. **RsyncLogWindow** - Already displays rsync logs:
   - Shows file changes in a tree view
   - Can be adapted for our needs

## What Needs to Be Implemented

### 1. **New Column: "Changes"** in Snapshot List

**Location**: `src/Gtk/SnapshotListBox.vala`

**Implementation**:
```vala
// Add column definition
private Gtk.TreeViewColumn col_changes;

// In init_treeview():
col_changes = new TreeViewColumn();
col_changes.title = _("Changes");
col_changes.resizable = true;
col_changes.min_width = 100;
var cell_changes = new CellRendererText();
col_changes.pack_start(cell_changes, false);
col_changes.set_cell_data_func(cell_changes, cell_changes_render);
treeview.append_column(col_changes);

// Render function:
private void cell_changes_render(...) {
    Snapshot bak;
    model.get(iter, 0, out bak, -1);
    
    var ctxt = (cell as Gtk.CellRendererText);
    
    if (bak.btrfs_mode) {
        ctxt.text = _("N/A"); // BTRFS doesn't have rsync logs
    } else {
        // Parse change count from rsync-log-changes
        int changes = bak.get_change_count();
        if (changes > 0) {
            ctxt.text = "%d files".printf(changes);
        } else {
            ctxt.text = _("Unknown");
        }
    }
}
```

**Complexity**: ⭐⭐ (Easy)

---

### 2. **Snapshot.get_change_count()** Method

**Location**: `src/Core/Snapshot.vala`

**Implementation**:
```vala
public int change_count = 0;  // New property

public int get_change_count() {
    if (change_count > 0) {
        return change_count; // Cached
    }
    
    if (btrfs_mode) {
        return 0; // BTRFS doesn't track file changes
    }
    
    // Parse rsync-log-changes file
    if (file_exists(rsync_changes_log_file)) {
        var task = new RsyncTask();
        var items = task.parse_log(rsync_changes_log_file);
        
        // Count only meaningful changes
        int count = 0;
        foreach (var item in items) {
            if (item.file_status == FileStatus.CREATED ||
                item.file_status == FileStatus.DELETED ||
                item.file_status == FileStatus.MODIFIED) {
                count++;
            }
        }
        
        change_count = count;
        return count;
    }
    
    return 0;
}

public ChangesSummary get_changes_summary() {
    // Returns detailed breakdown
    var summary = new ChangesSummary();
    
    if (file_exists(rsync_changes_log_file)) {
        var task = new RsyncTask();
        var items = task.parse_log(rsync_changes_log_file);
        
        foreach (var item in items) {
            switch (item.file_status) {
                case FileStatus.CREATED:
                    summary.files_created++;
                    summary.created_items.add(item);
                    break;
                case FileStatus.DELETED:
                    summary.files_deleted++;
                    summary.deleted_items.add(item);
                    break;
                case FileStatus.MODIFIED:
                    summary.files_modified++;
                    summary.modified_items.add(item);
                    break;
            }
        }
    }
    
    return summary;
}
```

**Complexity**: ⭐⭐⭐ (Medium)

---

### 3. **ChangesSummary Class** (New)

**Location**: `src/Core/ChangesSummary.vala` (NEW FILE)

**Implementation**:
```vala
public class ChangesSummary : GLib.Object {
    public int files_created = 0;
    public int files_deleted = 0;
    public int files_modified = 0;
    
    public Gee.ArrayList<FileItem> created_items;
    public Gee.ArrayList<FileItem> deleted_items;
    public Gee.ArrayList<FileItem> modified_items;
    
    public ChangesSummary() {
        created_items = new Gee.ArrayList<FileItem>();
        deleted_items = new Gee.ArrayList<FileItem>();
        modified_items = new Gee.ArrayList<FileItem>();
    }
    
    public int total_changes {
        get {
            return files_created + files_deleted + files_modified;
        }
    }
    
    public string summary_text {
        owned get {
            string txt = "";
            if (files_created > 0) {
                txt += "%d created, ".printf(files_created);
            }
            if (files_modified > 0) {
                txt += "%d modified, ".printf(files_modified);
            }
            if (files_deleted > 0) {
                txt += "%d deleted".printf(files_deleted);
            }
            return txt.strip().replace(", $", "");
        }
    }
    
    public Gee.ArrayList<string> get_major_changes() {
        // Identify major changes (system files, packages, etc.)
        var major = new Gee.ArrayList<string>();
        
        foreach (var item in created_items) {
            if (is_major_change(item)) {
                major.add("+ " + item.file_path);
            }
        }
        
        foreach (var item in deleted_items) {
            if (is_major_change(item)) {
                major.add("- " + item.file_path);
            }
        }
        
        foreach (var item in modified_items) {
            if (is_major_change(item)) {
                major.add("M " + item.file_path);
            }
        }
        
        return major;
    }
    
    private bool is_major_change(FileItem item) {
        // Identify system-critical changes
        string path = item.file_path;
        
        // Package installations/removals
        if (path.has_prefix("/usr/bin/") ||
            path.has_prefix("/usr/sbin/") ||
            path.has_prefix("/usr/lib/") ||
            path.has_prefix("/lib/")) {
            return true;
        }
        
        // System configuration
        if (path.has_prefix("/etc/")) {
            return true;
        }
        
        // Kernel/boot files
        if (path.has_prefix("/boot/")) {
            return true;
        }
        
        return false;
    }
}
```

**Complexity**: ⭐⭐⭐ (Medium)

---

### 4. **ChangesDetailsWindow** (New Dialog)

**Location**: `src/Gtk/ChangesDetailsWindow.vala` (NEW FILE)

**Implementation**:
```vala
public class ChangesDetailsWindow : Gtk.Dialog {
    
    private Snapshot snapshot;
    private Gtk.TreeView treeview;
    private Gtk.Label lbl_summary;
    private Gtk.Notebook notebook;
    
    public ChangesDetailsWindow(Snapshot snap, Gtk.Window parent) {
        
        snapshot = snap;
        set_transient_for(parent);
        set_modal(true);
        title = _("Changes in Snapshot: %s").printf(snap.name);
        set_default_size(800, 600);
        
        var content = get_content_area();
        content.margin = 12;
        
        // Summary header
        lbl_summary = new Gtk.Label("");
        lbl_summary.use_markup = true;
        lbl_summary.margin = 12;
        content.add(lbl_summary);
        
        // Notebook with tabs
        notebook = new Gtk.Notebook();
        content.add(notebook);
        
        // Tab 1: All Changes
        var all_changes_box = create_all_changes_tab();
        notebook.append_page(all_changes_box, new Gtk.Label(_("All Changes")));
        
        // Tab 2: Major Changes
        var major_changes_box = create_major_changes_tab();
        notebook.append_page(major_changes_box, new Gtk.Label(_("Major Changes")));
        
        // Tab 3: Packages
        var packages_box = create_packages_tab();
        notebook.append_page(packages_box, new Gtk.Label(_("Packages")));
        
        // Tab 4: Configuration Files
        var config_box = create_config_tab();
        notebook.append_page(config_box, new Gtk.Label(_("Config Files")));
        
        // Buttons
        add_button(_("Close"), Gtk.ResponseType.CLOSE);
        add_button(_("Export Changes"), Gtk.ResponseType.ACCEPT);
        
        load_changes();
        show_all();
    }
    
    private void load_changes() {
        var summary = snapshot.get_changes_summary();
        
        // Update summary label
        lbl_summary.label = "<b>Summary:</b> %s".printf(summary.summary_text);
        
        // Populate tabs
        populate_all_changes(summary);
        populate_major_changes(summary);
        populate_packages(summary);
        populate_config_files(summary);
    }
    
    private Gtk.Box create_all_changes_tab() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        
        // TreeView with columns: Status, File Path, Size
        treeview = new Gtk.TreeView();
        
        // Column: Status (icon + text)
        var col_status = new Gtk.TreeViewColumn();
        col_status.title = _("Status");
        var cell_icon = new Gtk.CellRendererPixbuf();
        var cell_text = new Gtk.CellRendererText();
        col_status.pack_start(cell_icon, false);
        col_status.pack_start(cell_text, false);
        treeview.append_column(col_status);
        
        // Column: File Path
        var col_path = new Gtk.TreeViewColumn();
        col_path.title = _("File Path");
        col_path.expand = true;
        var cell_path = new Gtk.CellRendererText();
        col_path.pack_start(cell_path, true);
        treeview.append_column(col_path);
        
        // Column: Size
        var col_size = new Gtk.TreeViewColumn();
        col_size.title = _("Size");
        var cell_size = new Gtk.CellRendererText();
        col_size.pack_start(cell_size, false);
        treeview.append_column(col_size);
        
        var scrolled = new Gtk.ScrolledWindow(null, null);
        scrolled.add(treeview);
        box.add(scrolled);
        
        return box;
    }
    
    private void populate_all_changes(ChangesSummary summary) {
        var model = new Gtk.ListStore(4, 
            typeof(string),  // Status
            typeof(string),  // Icon name
            typeof(string),  // File path
            typeof(string)); // Size
        
        Gtk.TreeIter iter;
        
        // Add created files
        foreach (var item in summary.created_items) {
            model.append(out iter);
            model.set(iter, 
                0, "Created",
                1, "list-add",
                2, item.file_path,
                3, format_file_size(item.file_size));
        }
        
        // Add modified files
        foreach (var item in summary.modified_items) {
            model.append(out iter);
            model.set(iter,
                0, "Modified",
                1, "document-edit",
                2, item.file_path,
                3, format_file_size(item.file_size));
        }
        
        // Add deleted files
        foreach (var item in summary.deleted_items) {
            model.append(out iter);
            model.set(iter,
                0, "Deleted",
                1, "list-remove",
                2, item.file_path,
                3, "");
        }
        
        treeview.set_model(model);
    }
    
    // Similar methods for other tabs...
}
```

**Complexity**: ⭐⭐⭐⭐ (Complex)

---

### 5. **Menu Item: "View Changes Details"**

**Location**: `src/Gtk/SnapshotListBox.vala`

**Implementation**:
```vala
// In init_list_view_context_menu():

// mi_view_changes
item = new ImageMenuItem.with_label(_("View Changes Details..."));
item.image = IconManager.lookup_image("document-properties", 16);
item.activate.connect(() => { view_changes_details(); });
menu_snapshots.append(item);
mi_view_changes = item;

// Signal
public signal void view_changes_details();
```

**In MainWindow.vala**:
```vala
// Connect signal
snapshot_list_box.view_changes_details.connect(show_changes_details);

// Handler
public void show_changes_details() {
    var selected = snapshot_list_box.selected_snapshots();
    
    if (selected.size == 0) {
        gtk_messagebox(
            _("Select Snapshot"),
            _("Please select a snapshot to view changes!"),
            this, false);
        return;
    }
    
    var snapshot = selected[0];
    
    if (snapshot.btrfs_mode) {
        gtk_messagebox(
            _("Not Available"),
            _("Change tracking is only available for RSYNC snapshots."),
            this, false);
        return;
    }
    
    var dialog = new ChangesDetailsWindow(snapshot, this);
    dialog.run();
    dialog.destroy();
}
```

**Complexity**: ⭐⭐ (Easy)

---

## Implementation Checklist

### Phase 1: Basic Changes Column (Easy)
- [ ] Add `change_count` property to Snapshot class
- [ ] Add `get_change_count()` method
- [ ] Add "Changes" column to SnapshotListBox
- [ ] Implement `cell_changes_render()`
- [ ] Test with existing snapshots

**Estimated Time**: 2-3 hours

### Phase 2: Changes Summary (Medium)
- [ ] Create `ChangesSummary.vala` class
- [ ] Implement `get_changes_summary()` in Snapshot
- [ ] Implement `is_major_change()` logic
- [ ] Test summary generation

**Estimated Time**: 3-4 hours

### Phase 3: Changes Details Dialog (Complex)
- [ ] Create `ChangesDetailsWindow.vala`
- [ ] Implement "All Changes" tab
- [ ] Implement "Major Changes" tab
- [ ] Implement "Packages" tab (detect package files)
- [ ] Implement "Config Files" tab
- [ ] Add export functionality

**Estimated Time**: 6-8 hours

### Phase 4: Integration & Polish (Medium)
- [ ] Add menu item to context menu
- [ ] Connect signals in MainWindow
- [ ] Add keyboard shortcut (e.g., Ctrl+D for Details)
- [ ] Add tooltips
- [ ] Test with various snapshots
- [ ] Handle edge cases (no changes, missing logs, etc.)

**Estimated Time**: 2-3 hours

---

## Total Estimated Time: 13-18 hours

---

## Files to Create

1. **`src/Core/ChangesSummary.vala`** - NEW
2. **`src/Gtk/ChangesDetailsWindow.vala`** - NEW

## Files to Modify

1. **`src/Core/Snapshot.vala`**
   - Add `change_count` property
   - Add `get_change_count()` method
   - Add `get_changes_summary()` method

2. **`src/Gtk/SnapshotListBox.vala`**
   - Add `col_changes` column
   - Add `cell_changes_render()` method
   - Add "View Changes Details" menu item
   - Add `view_changes_details` signal

3. **`src/Gtk/MainWindow.vala`**
   - Add `show_changes_details()` handler
   - Connect signal

4. **`src/meson.build`**
   - Add new source files to build

---

## Benefits

### For Users:
1. ✅ **See what changed** between snapshots
2. ✅ **Identify major changes** (packages, config files)
3. ✅ **Understand impact** before restoring
4. ✅ **Selective restore** (know what will be reverted)
5. ✅ **Audit trail** (what was installed/removed)

### Use Cases:
1. **Before Restore**: See what will change
2. **Troubleshooting**: Identify what broke the system
3. **Audit**: Track system changes over time
4. **Compliance**: Document system modifications

---

## Example UI

### Snapshot List (with Changes column):
```
Snapshot              | System | Tags | Size    | Changes      | Comments
2025-11-23_17-00-00  | Ubuntu | O    | 2.5 GB  | 142 files    | After update
2025-11-23_16-00-00  | Ubuntu | D    | 2.4 GB  | 23 files     | Daily backup
2025-11-22_16-00-00  | Ubuntu | D    | 2.3 GB  | 8 files      | Daily backup
```

### Changes Details Dialog:
```
┌─ Changes in Snapshot: 2025-11-23_17-00-00 ────────────┐
│                                                        │
│ Summary: 142 created, 18 modified, 5 deleted          │
│                                                        │
│ ┌─ All Changes ─┬─ Major Changes ─┬─ Packages ─┬─ Config Files ─┐
│ │                                                                 │
│ │ Status    │ File Path                      │ Size              │
│ │ ──────────┼────────────────────────────────┼──────────         │
│ │ Created   │ /usr/bin/firefox               │ 245 MB            │
│ │ Created   │ /usr/lib/firefox/...           │ 1.2 GB            │
│ │ Modified  │ /etc/apt/sources.list          │ 2.5 KB            │
│ │ Deleted   │ /usr/bin/old-app               │ -                 │
│ │                                                                 │
│ └─────────────────────────────────────────────────────────────────┘
│                                                                    │
│                                  [ Export Changes ] [ Close ]      │
└────────────────────────────────────────────────────────────────────┘
```

---

## Next Steps

Would you like me to:
1. **Implement Phase 1** (Basic Changes Column) - Quick win, 2-3 hours
2. **Create full implementation plan** with detailed code
3. **Start with the complete implementation** (all phases)

Let me know which approach you prefer!
