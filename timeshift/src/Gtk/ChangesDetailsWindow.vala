/*
 * ChangesDetailsWindow.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class ChangesDetailsWindow : Gtk.Dialog {
	
	private Snapshot snapshot;
	private ChangesSummary summary;
	private Gtk.Label lbl_summary;
	private Gtk.Notebook notebook;
	private Gtk.TreeView tv_all;
	private Gtk.TreeView tv_major;
	private Gtk.TreeView tv_packages;
	private Gtk.TreeView tv_config;
	
	public ChangesDetailsWindow(Snapshot snap, Gtk.Window parent) {
		
		snapshot = snap;
		set_transient_for(parent);
		set_modal(true);
		set_default_size(900, 600);
		window_position = WindowPosition.CENTER_ON_PARENT;
		
		title = _("Changes in Snapshot: %s").printf(snap.name);
		
		// Get changes summary
		summary = snapshot.get_changes_summary();
		
		init_ui();
		load_changes();
		show_all();
	}
	
	private void init_ui() {
		
		var content = get_content_area();
		content.margin = 12;
		content.spacing = 6;
		
		// Header with snapshot info
		var hbox_header = new Gtk.Box(Orientation.HORIZONTAL, 12);
		content.add(hbox_header);
		
		var lbl_snapshot = new Gtk.Label("");
		lbl_snapshot.set_markup("<b>%s:</b> %s".printf(_("Snapshot"), snapshot.name));
		lbl_snapshot.xalign = 0;
		hbox_header.add(lbl_snapshot);
		
		// Summary label
		lbl_summary = new Gtk.Label("");
		lbl_summary.use_markup = true;
		lbl_summary.xalign = 0;
		lbl_summary.margin = 6;
		content.add(lbl_summary);
		
		// Separator
		content.add(new Gtk.Separator(Orientation.HORIZONTAL));
		
		// Notebook with tabs
		notebook = new Gtk.Notebook();
		notebook.expand = true;
		content.add(notebook);
		
		// Tab 1: All Changes
		tv_all = create_treeview();
		var scroll_all = new Gtk.ScrolledWindow(null, null);
		scroll_all.add(tv_all);
		notebook.append_page(scroll_all, new Gtk.Label(_("All Changes (%d)").printf(summary.total_changes)));
		
		// Tab 2: Major Changes
		tv_major = create_treeview();
		var scroll_major = new Gtk.ScrolledWindow(null, null);
		scroll_major.add(tv_major);
		var major_count = summary.get_major_changes().size;
		notebook.append_page(scroll_major, new Gtk.Label(_("Major Changes (%d)").printf(major_count)));
		
		// Tab 3: Packages
		tv_packages = create_treeview();
		var scroll_packages = new Gtk.ScrolledWindow(null, null);
		scroll_packages.add(tv_packages);
		var pkg_count = summary.get_package_changes().size;
		notebook.append_page(scroll_packages, new Gtk.Label(_("Packages (%d)").printf(pkg_count)));
		
		// Tab 4: Configuration Files
		tv_config = create_treeview();
		var scroll_config = new Gtk.ScrolledWindow(null, null);
		scroll_config.add(tv_config);
		var cfg_count = summary.get_config_changes().size;
		notebook.append_page(scroll_config, new Gtk.Label(_("Config Files (%d)").printf(cfg_count)));
		
		// Buttons
		add_button(_("Export List"), Gtk.ResponseType.ACCEPT);
		add_button(_("Close"), Gtk.ResponseType.CLOSE);
		
		response.connect((response_id) => {
			if (response_id == Gtk.ResponseType.ACCEPT) {
				export_changes();
			}
		});
	}
	
	private Gtk.TreeView create_treeview() {
		
		var treeview = new Gtk.TreeView();
		treeview.headers_visible = true;
		treeview.reorderable = false;
		treeview.get_selection().mode = SelectionMode.MULTIPLE;
		
		// Column: Status Icon
		var col_icon = new Gtk.TreeViewColumn();
		col_icon.title = "";
		var cell_icon = new Gtk.CellRendererPixbuf();
		col_icon.pack_start(cell_icon, false);
		col_icon.set_attributes(cell_icon, "icon-name", 0);
		treeview.append_column(col_icon);
		
		// Column: Status Text
		var col_status = new Gtk.TreeViewColumn();
		col_status.title = _("Status");
		col_status.resizable = true;
		col_status.min_width = 80;
		var cell_status = new Gtk.CellRendererText();
		col_status.pack_start(cell_status, false);
		col_status.set_attributes(cell_status, "text", 1);
		treeview.append_column(col_status);
		
		// Column: File Path
		var col_path = new Gtk.TreeViewColumn();
		col_path.title = _("File Path");
		col_path.resizable = true;
		col_path.expand = true;
		var cell_path = new Gtk.CellRendererText();
		cell_path.ellipsize = Pango.EllipsizeMode.MIDDLE;
		col_path.pack_start(cell_path, true);
		col_path.set_attributes(cell_path, "text", 2);
		treeview.append_column(col_path);
		
		// Column: Size
		var col_size = new Gtk.TreeViewColumn();
		col_size.title = _("Size");
		col_size.resizable = true;
		col_size.min_width = 80;
		var cell_size = new Gtk.CellRendererText();
		cell_size.xalign = 1.0f;
		col_size.pack_start(cell_size, false);
		col_size.set_attributes(cell_size, "text", 3);
		treeview.append_column(col_size);
		
		return treeview;
	}
	
	private void load_changes() {
		
		// Update summary label
		if (summary.total_changes == 0) {
			lbl_summary.label = "<b>%s</b>".printf(_("No changes found"));
		} else {
			lbl_summary.label = "<b>%s:</b> %s".printf(_("Summary"), summary.summary_text);
		}
		
		// Populate tabs
		populate_treeview(tv_all, summary.all_items);
		populate_treeview(tv_major, summary.get_major_changes());
		populate_treeview(tv_packages, summary.get_package_changes());
		populate_treeview(tv_config, summary.get_config_changes());
	}
	
	private void populate_treeview(Gtk.TreeView treeview, Gee.ArrayList<FileItem> items) {
		
		// Model: icon_name, status_text, file_path, size_text
		var model = new Gtk.ListStore(4,
			typeof(string),  // Icon name
			typeof(string),  // Status text
			typeof(string),  // File path
			typeof(string)); // Size
		
		Gtk.TreeIter iter;
		
		foreach (var item in items) {
			model.append(out iter);
			model.set(iter,
				0, summary.get_status_icon(item),
				1, summary.get_status_text(item),
				2, item.file_path,
				3, (item.file_status == "deleted") ? "—" : format_file_size(item.size));
		}
		
		treeview.set_model(model);
	}
	
	private void export_changes() {
		
		var dialog = new Gtk.FileChooserDialog(
			_("Export Changes List"),
			this,
			Gtk.FileChooserAction.SAVE,
			_("Cancel"), Gtk.ResponseType.CANCEL,
			_("Save"), Gtk.ResponseType.ACCEPT
		);
		
		dialog.set_current_name("snapshot-changes-%s.txt".printf(snapshot.name));
		
		if (dialog.run() == Gtk.ResponseType.ACCEPT) {
			string file_path = dialog.get_filename();
			
			// Build export text
			string txt = "";
			txt += "Snapshot Changes Report\n";
			txt += "======================\n\n";
			txt += "Snapshot: %s\n".printf(snapshot.name);
			txt += "Date: %s\n".printf(snapshot.date_formatted);
			txt += "Summary: %s\n\n".printf(summary.summary_text);
			
			txt += "All Changes (%d)\n".printf(summary.total_changes);
			txt += "----------------\n";
			foreach (var item in summary.all_items) {
				txt += "%s\t%s\t%s\n".printf(
					summary.get_status_text(item),
					item.file_path,
					(item.file_status == "deleted") ? "" : format_file_size(item.size)
				);
			}
			
			// Save to file
			if (file_write(file_path, txt)) {
				gtk_messagebox(
					_("Export Complete"),
					_("Changes list exported to:\n%s").printf(file_path),
					this, false
				);
			} else {
				gtk_messagebox(
					_("Export Failed"),
					_("Failed to export changes list."),
					this, true
				);
			}
		}
		
		dialog.destroy();
	}
}
