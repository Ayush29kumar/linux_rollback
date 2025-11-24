/*
 * ChangesSummary.vala
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

using GLib;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class ChangesSummary : GLib.Object {
	
	public int files_created = 0;
	public int files_deleted = 0;
	public int files_modified = 0;
	
	public Gee.ArrayList<FileItem> created_items;
	public Gee.ArrayList<FileItem> deleted_items;
	public Gee.ArrayList<FileItem> modified_items;
	public Gee.ArrayList<FileItem> all_items;
	
	public ChangesSummary() {
		created_items = new Gee.ArrayList<FileItem>();
		deleted_items = new Gee.ArrayList<FileItem>();
		modified_items = new Gee.ArrayList<FileItem>();
		all_items = new Gee.ArrayList<FileItem>();
	}
	
	public int total_changes {
		get {
			// Only count actual file changes, not directory metadata
			return files_created + files_deleted + files_modified;
		}
	}
	
	public int total_items {
		get {
			// Total items including directories
			return all_items.size;
		}
	}
	
	public string summary_text {
		owned get {
			var parts = new Gee.ArrayList<string>();
			
			if (files_created > 0) {
				parts.add(_("%d created").printf(files_created));
			}
			if (files_modified > 0) {
				parts.add(_("%d modified").printf(files_modified));
			}
			if (files_deleted > 0) {
				parts.add(_("%d deleted").printf(files_deleted));
			}
			
			if (parts.size == 0) {
				return _("No changes");
			}
			
			return string.joinv(", ", parts.to_array());
		}
	}
	
	public Gee.ArrayList<FileItem> get_major_changes() {
		/* Returns only system-critical changes */
		
		var major = new Gee.ArrayList<FileItem>();
		
		foreach (var item in all_items) {
			if (is_major_change(item)) {
				major.add(item);
			}
		}
		
		return major;
	}
	
	public Gee.ArrayList<FileItem> get_package_changes() {
		/* Returns package-related changes */
		
		var packages = new Gee.ArrayList<FileItem>();
		
		foreach (var item in all_items) {
			if (is_package_file(item)) {
				packages.add(item);
			}
		}
		
		return packages;
	}
	
	public Gee.ArrayList<FileItem> get_config_changes() {
		/* Returns configuration file changes */
		
		var configs = new Gee.ArrayList<FileItem>();
		
		foreach (var item in all_items) {
			if (is_config_file(item)) {
				configs.add(item);
			}
		}
		
		return configs;
	}
	
	private bool is_major_change(FileItem item) {
		/* Identify system-critical changes */
		
		string path = item.file_path;
		
		// Normalize path - ensure it starts with /
		if (!path.has_prefix("/")) {
			path = "/" + path;
		}
		
		// Package installations/removals
		if (path.has_prefix("/usr/bin/") ||
		    path.has_prefix("/usr/sbin/") ||
		    path.has_prefix("/usr/lib/") ||
		    path.has_prefix("/lib/") ||
		    path.has_prefix("/lib64/") ||
		    path.contains("/usr/bin/") ||
		    path.contains("/usr/sbin/") ||
		    path.contains("/usr/lib/")) {
			return true;
		}
		
		// System configuration
		if (path.has_prefix("/etc/") || path.contains("/etc/")) {
			return true;
		}
		
		// Kernel/boot files
		if (path.has_prefix("/boot/") || path.contains("/boot/")) {
			return true;
		}
		
		// System binaries
		if (path.has_prefix("/sbin/") || path.contains("/sbin/")) {
			return true;
		}
		
		return false;
	}
	
	private bool is_package_file(FileItem item) {
		/* Identify package-related files */
		
		string path = item.file_path;
		
		// Normalize path
		if (!path.has_prefix("/")) {
			path = "/" + path;
		}
		
		return path.has_prefix("/usr/bin/") ||
		       path.has_prefix("/usr/sbin/") ||
		       path.has_prefix("/usr/lib/") ||
		       path.has_prefix("/usr/share/") ||
		       path.has_prefix("/lib/") ||
		       path.has_prefix("/lib64/") ||
		       path.contains("/usr/bin/") ||
		       path.contains("/usr/sbin/") ||
		       path.contains("/usr/lib/") ||
		       path.contains("/usr/share/");
	}
	
	private bool is_config_file(FileItem item) {
		/* Identify configuration files */
		
		string path = item.file_path;
		
		// Normalize path
		if (!path.has_prefix("/")) {
			path = "/" + path;
		}
		
		return path.has_prefix("/etc/") || path.contains("/etc/");
	}
	
	public string get_status_icon(FileItem item) {
		/* Get icon name for file status */
		
		switch (item.file_status) {
			case "created":
				return "list-add";
			case "deleted":
				return "list-remove";
			case "modified":
				return "document-edit";
			default:
				return "text-x-generic";
		}
	}
	
	public string get_status_text(FileItem item) {
		/* Get human-readable status text */
		
		switch (item.file_status) {
			case "created":
				return _("Created");
			case "deleted":
				return _("Deleted");
			case "modified":
				return _("Modified");
			default:
				return _("Unknown");
		}
	}
}
