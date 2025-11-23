# LinuxRollback User Configuration Backup Enhancement

## Overview
This document outlines the implementation plan for adding user configuration backup to LinuxRollback (formerly Timeshift).

## Problem Statement
Currently, LinuxRollback excludes all user data by default, including:
- WiFi passwords (`/etc/NetworkManager/system-connections/`)
- Bluetooth device pairings (`/var/lib/bluetooth/`)
- Desktop customizations ("ricing"): themes, icons, fonts, wallpapers
- Application configurations in `~/.config/`
- Shell configurations (`.bashrc`, `.zshrc`, etc.)
- Browser profiles and settings
- SSH keys and GPG keys

## Solution: User Config Backup Mode

### New Features to Implement:

1. **Add `include_user_configs` boolean flag** to Main.vala
2. **Create smart include patterns** for essential user configurations
3. **Add GUI toggle** in Settings → Users tab
4. **Preserve system-level network/bluetooth configs**

### Files to Modify:

#### 1. `src/Core/Main.vala`
- Add `public bool include_user_configs = false;` property
- Modify `add_default_exclude_entries()` to conditionally include user configs
- Add new method `add_user_config_include_patterns()`

#### 2. `src/Gtk/UsersBox.vala`
- Add checkbox: "Include User Configurations (WiFi, Bluetooth, Desktop Customizations)"
- Add tooltip explaining what's included

#### 3. `src/Core/Main.vala` - New Include Patterns

```vala
public void add_user_config_include_patterns() {
    // System-level configs (always backed up regardless of user data)
    exclude_list_user.add("+ /etc/NetworkManager/system-connections/**");
    exclude_list_user.add("+ /var/lib/bluetooth/**");
    exclude_list_user.add("+ /var/lib/NetworkManager/**");
    
    if (include_user_configs) {
        // Desktop Environment configs
        exclude_list_user.add("+ /home/*/.config/gtk-3.0/**");
        exclude_list_user.add("+ /home/*/.config/gtk-4.0/**");
        exclude_list_user.add("+ /home/*/.config/kde*/**");
        exclude_list_user.add("+ /home/*/.config/plasma*/**");
        exclude_list_user.add("+ /home/*/.config/xfce4/**");
        exclude_list_user.add("+ /home/*/.config/cinnamon/**");
        exclude_list_user.add("+ /home/*/.config/mate/**");
        exclude_list_user.add("+ /home/*/.config/lxqt/**");
        
        // Themes and customizations
        exclude_list_user.add("+ /home/*/.themes/**");
        exclude_list_user.add("+ /home/*/.icons/**");
        exclude_list_user.add("+ /home/*/.fonts/**");
        exclude_list_user.add("+ /home/*/.local/share/themes/**");
        exclude_list_user.add("+ /home/*/.local/share/icons/**");
        exclude_list_user.add("+ /home/*/.local/share/fonts/**");
        exclude_list_user.add("+ /home/*/.local/share/plasma/**");
        
        // Shell configs
        exclude_list_user.add("+ /home/*/.bashrc");
        exclude_list_user.add("+ /home/*/.bash_profile");
        exclude_list_user.add("+ /home/*/.bash_aliases");
        exclude_list_user.add("+ /home/*/.zshrc");
        exclude_list_user.add("+ /home/*/.zsh_history");
        exclude_list_user.add("+ /home/*/.oh-my-zsh/**");
        exclude_list_user.add("+ /home/*/.profile");
        exclude_list_user.add("+ /home/*/.xinitrc");
        exclude_list_user.add("+ /home/*/.xprofile");
        
        // Terminal emulator configs
        exclude_list_user.add("+ /home/*/.config/alacritty/**");
        exclude_list_user.add("+ /home/*/.config/kitty/**");
        exclude_list_user.add("+ /home/*/.config/terminator/**");
        
        // Window manager configs
        exclude_list_user.add("+ /home/*/.config/i3/**");
        exclude_list_user.add("+ /home/*/.config/sway/**");
        exclude_list_user.add("+ /home/*/.config/bspwm/**");
        exclude_list_user.add("+ /home/*/.config/awesome/**");
        exclude_list_user.add("+ /home/*/.config/openbox/**");
        
        // Application launchers
        exclude_list_user.add("+ /home/*/.config/rofi/**");
        exclude_list_user.add("+ /home/*/.config/dmenu/**");
        exclude_list_user.add("+ /home/*/.config/ulauncher/**");
        
        // Status bars
        exclude_list_user.add("+ /home/*/.config/polybar/**");
        exclude_list_user.add("+ /home/*/.config/waybar/**");
        
        // Browser profiles (excluding cache)
        exclude_list_user.add("+ /home/*/.mozilla/firefox/**.default/prefs.js");
        exclude_list_user.add("+ /home/*/.mozilla/firefox/**.default/extensions/**");
        exclude_list_user.add("+ /home/*/.mozilla/firefox/**.default/bookmarkbackups/**");
        exclude_list_user.add("+ /home/*/.config/google-chrome/Default/Preferences");
        exclude_list_user.add("+ /home/*/.config/chromium/Default/Preferences");
        
        // SSH and GPG (SECURITY SENSITIVE)
        exclude_list_user.add("+ /home/*/.ssh/config");
        exclude_list_user.add("+ /home/*/.ssh/known_hosts");
        exclude_list_user.add("+ /home/*/.ssh/*.pub");  // Public keys only
        exclude_list_user.add("+ /home/*/.gnupg/gpg.conf");
        exclude_list_user.add("+ /home/*/.gnupg/pubring.kbx");
        
        // Git config
        exclude_list_user.add("+ /home/*/.gitconfig");
        exclude_list_user.add("+ /home/*/.config/git/**");
        
        // Editor configs
        exclude_list_user.add("+ /home/*/.vimrc");
        exclude_list_user.add("+ /home/*/.vim/**");
        exclude_list_user.add("+ /home/*/.config/nvim/**");
        exclude_list_user.add("+ /home/*/.emacs.d/**");
        exclude_list_user.add("+ /home/*/.config/Code/User/**");  // VS Code
        
        // Desktop files and autostart
        exclude_list_user.add("+ /home/*/.local/share/applications/**");
        exclude_list_user.add("+ /home/*/.config/autostart/**");
        
        // Wallpapers
        exclude_list_user.add("+ /home/*/.local/share/wallpapers/**");
        exclude_list_user.add("+ /home/*/Pictures/Wallpapers/**");
    }
}
```

## Implementation Steps:

1. Add the boolean flag to Main.vala
2. Modify the exclude list generation logic
3. Update the GUI to expose the option
4. Test with various desktop environments
5. Update documentation

## Security Considerations:

- **SSH Private Keys**: NOT backed up by default (only public keys and config)
- **Browser Passwords**: NOT backed up (stored in encrypted keyrings)
- **WiFi Passwords**: Backed up (encrypted by NetworkManager)
- **GPG Private Keys**: NOT backed up (only public keyring and config)

## Benefits:

1. ✅ Preserve desktop customizations after system restore
2. ✅ Maintain WiFi and Bluetooth connections
3. ✅ Keep application settings and preferences
4. ✅ Restore shell environment and aliases
5. ✅ Maintain git and development tool configurations

## Testing Checklist:

- [ ] Test with GNOME desktop
- [ ] Test with KDE Plasma
- [ ] Test with XFCE
- [ ] Test with i3/Sway
- [ ] Verify WiFi passwords are restored
- [ ] Verify Bluetooth devices reconnect
- [ ] Verify themes and icons are preserved
- [ ] Ensure private keys are NOT backed up
