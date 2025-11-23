# LinuxRollback Snapshot Changes - Test Documentation

## Test Suite Overview

This directory contains comprehensive test scripts to validate the snapshot changes/diff feature.

## Test Scripts

### 1. `quick-test.sh` - Quick Validation Test
**Purpose**: Rapid validation of basic functionality  
**Duration**: ~2 minutes  
**What it does**:
- Creates baseline snapshot
- Installs htop package
- Creates post-install snapshot
- Shows change count
- Displays sample changes

**Usage**:
```bash
sudo chmod +x quick-test.sh
sudo ./quick-test.sh
```

**Expected Result**:
- 2 snapshots created
- 5-15 file changes detected
- Changes visible in GUI

---

### 2. `test-snapshot-changes.sh` - Comprehensive Test Suite
**Purpose**: Full feature validation with 6 test cases  
**Duration**: ~10-15 minutes  
**What it does**:

#### Test Case 1: Baseline Snapshot
- Creates snapshot with minimal changes
- Expected: 0-10 changes

#### Test Case 2: Small Package Installation
- Installs htop
- Expected: 5+ changes
- Validates: Package file detection

#### Test Case 3: Configuration File Changes
- Modifies `/etc/hostname` and `/etc/hosts`
- Expected: 2+ changes
- Validates: Config file tracking

#### Test Case 4: Large Package Installation
- Installs GIMP
- Expected: 100+ changes
- Validates: Large change handling

#### Test Case 5: Custom File Creation
- Creates files in `/usr/local/`
- Expected: 2+ changes
- Validates: Custom file detection

#### Test Case 6: Mixed Changes
- Package install + config changes + file creation
- Expected: 10+ changes
- Validates: Multiple change types

**Usage**:
```bash
sudo chmod +x test-snapshot-changes.sh
sudo ./test-snapshot-changes.sh
```

**Output**:
- Colored console output
- Test results log: `/tmp/linuxrollback-test/test-results.log`
- Summary report with pass/fail counts

---

### 3. `cleanup-test-snapshots.sh` - Cleanup Script
**Purpose**: Remove all test artifacts  
**What it removes**:
- All test snapshots (matching "Test [0-9]:")
- Installed packages (htop, gimp, curl)
- Test files in `/usr/local/`
- Config file backups
- Test directory

**Usage**:
```bash
sudo chmod +x cleanup-test-snapshots.sh
sudo ./cleanup-test-snapshots.sh
```

---

## Test Workflow

### Quick Test (Recommended for first-time validation)

```bash
# 1. Run quick test
sudo ./quick-test.sh

# 2. Open GUI to verify
sudo linuxrollback-gtk

# 3. Check:
#    - "Changes" column shows number
#    - Right-click → "View Changes Details..." works
#    - Tabs show categorized changes

# 4. Clean up
sudo ./cleanup-test-snapshots.sh
```

### Full Test Suite (Comprehensive validation)

```bash
# 1. Run full test suite
sudo ./test-snapshot-changes.sh

# 2. Review results
cat /tmp/linuxrollback-test/test-results.log

# 3. Open GUI for manual verification
sudo linuxrollback-gtk

# 4. Clean up
sudo ./cleanup-test-snapshots.sh
```

---

## Expected Results

### Quick Test
```
✓ Baseline snapshot created
✓ Package installed
✓ Post-install snapshot created
✓ Found 8 file changes

Sample changes:
created /usr/bin/htop
created /usr/share/doc/htop/...
created /usr/share/man/man1/htop.1.gz
...
```

### Full Test Suite
```
TEST 1: Baseline Snapshot         [PASSED]
TEST 2: Small Package Installation [PASSED]
TEST 3: Configuration File Changes [PASSED]
TEST 4: Large Package Installation [PASSED]
TEST 5: Custom File Creation       [PASSED]
TEST 6: Mixed Changes              [PASSED]

Total Tests: 6
Passed: 6
Failed: 0

ALL TESTS PASSED!
```

---

## GUI Verification Checklist

After running tests, verify in GUI:

- [ ] **Changes Column Visible**
  - Column appears in snapshot list
  - Shows numbers for test snapshots
  - Shows "—" for BTRFS snapshots

- [ ] **Changes Details Dialog**
  - Right-click menu shows "View Changes Details..."
  - Dialog opens for RSYNC snapshots
  - Shows "Not Available" for BTRFS snapshots

- [ ] **All Changes Tab**
  - Lists all changed files
  - Shows status icons (Created/Modified/Deleted)
  - Shows file paths and sizes
  - Sortable columns

- [ ] **Major Changes Tab**
  - Shows only system-critical files
  - Includes `/etc/`, `/usr/bin/`, `/boot/`
  - Count matches or is less than All Changes

- [ ] **Packages Tab**
  - Shows package-related files
  - Includes `/usr/lib/`, `/usr/share/`
  - htop/gimp files visible

- [ ] **Config Files Tab**
  - Shows `/etc/` changes only
  - hostname and hosts visible (Test 3)

- [ ] **Export Functionality**
  - "Export List" button works
  - File chooser dialog appears
  - Exported file contains change list
  - Format: Status | File Path | Size

---

## Troubleshooting

### Issue: No changes detected
**Solution**:
- Check if RSYNC mode is enabled (not BTRFS)
- Verify rsync-log-changes file exists in snapshot
- Run: `ls -la /timeshift/snapshots/[snapshot-name]/`

### Issue: Changes column shows "—"
**Possible causes**:
- BTRFS mode (expected behavior)
- Old snapshot without rsync-log-changes
- Snapshot not yet created

### Issue: "View Changes Details..." disabled
**Possible causes**:
- BTRFS snapshot selected (only works for RSYNC)
- No snapshot selected
- Multiple snapshots selected

### Issue: Test script fails
**Check**:
- Running with sudo
- LinuxRollback installed correctly
- Sufficient disk space
- Network connection (for package downloads)

---

## Manual Test Cases

### Test Case: Desktop Customization
```bash
# 1. Create baseline
sudo linuxrollback --create --comments "Before customization"

# 2. Make changes
mkdir -p ~/.themes/MyTheme
echo "Test theme" > ~/.themes/MyTheme/index.theme
mkdir -p ~/.icons/MyIcons
echo "Test icon" > ~/.icons/MyIcons/index.theme

# 3. Create snapshot
sudo linuxrollback --create --comments "After customization"

# 4. Verify in GUI
# Note: User home changes may not be tracked by default
```

### Test Case: System Update
```bash
# 1. Create baseline
sudo linuxrollback --create --comments "Before update"

# 2. Update system
sudo apt-get update
sudo apt-get upgrade -y

# 3. Create snapshot
sudo linuxrollback --create --comments "After update"

# 4. Check changes (should show many)
```

### Test Case: Service Installation
```bash
# 1. Create baseline
sudo linuxrollback --create --comments "Before nginx"

# 2. Install nginx
sudo apt-get install -y nginx

# 3. Create snapshot
sudo linuxrollback --create --comments "After nginx"

# 4. Verify config files in /etc/nginx/
```

---

## Performance Benchmarks

Expected performance on standard hardware:

| Test Case | Snapshot Time | Change Detection | Dialog Load |
|-----------|---------------|------------------|-------------|
| Baseline  | 10-30s        | < 1s             | < 1s        |
| Small Pkg | 10-30s        | < 1s             | < 1s        |
| Config    | 10-30s        | < 1s             | < 1s        |
| Large Pkg | 30-60s        | 1-2s             | 1-2s        |
| Custom    | 10-30s        | < 1s             | < 1s        |
| Mixed     | 20-40s        | 1-2s             | 1-2s        |

---

## Test Data

### Sample Change Counts by Test

| Test | Min Changes | Typical | Max |
|------|-------------|---------|-----|
| 1. Baseline | 0 | 2-5 | 10 |
| 2. htop | 5 | 8-12 | 20 |
| 3. Config | 2 | 2-3 | 5 |
| 4. GIMP | 100 | 150-300 | 500 |
| 5. Custom | 2 | 2-3 | 5 |
| 6. Mixed | 10 | 20-30 | 50 |

---

## Cleanup Verification

After running cleanup script, verify:

```bash
# Check snapshots removed
sudo linuxrollback --list | grep "Test"
# Should return nothing

# Check packages removed
dpkg -l | grep -E "htop|gimp|curl"
# Should show as not installed or removed

# Check files removed
ls /usr/local/bin/test-script
ls /usr/local/test.txt
# Should return "No such file"
```

---

## Continuous Testing

For ongoing development, create a cron job:

```bash
# Run tests weekly
0 2 * * 0 /path/to/test-snapshot-changes.sh && /path/to/cleanup-test-snapshots.sh
```

---

## Contributing Test Cases

To add new test cases:

1. Add function to `test-snapshot-changes.sh`:
```bash
test_my_feature() {
    print_info "TEST X: My Feature"
    # Your test code
    create_snapshot "Test X: Description"
    check_snapshot_changes "$snapshot" MIN_CHANGES
}
```

2. Call in `main()` function
3. Update cleanup script if needed
4. Document in this README

---

## Support

If tests fail consistently:
1. Check `/tmp/linuxrollback-test/test-results.log`
2. Verify LinuxRollback installation
3. Check system requirements
4. Review snapshot logs in `/var/log/timeshift/`

---

**Last Updated**: 2025-11-23  
**Version**: 1.0  
**Tested On**: Ubuntu 24.04 LTS
