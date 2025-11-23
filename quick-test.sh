#!/bin/bash
#
# Quick Test Script for Snapshot Changes Feature
# Performs a simple install/snapshot/remove cycle
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Quick Snapshot Changes Test                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Step 1: Create baseline snapshot
echo -e "${BLUE}[1/5]${NC} Creating baseline snapshot..."
linuxrollback --create --comments "Quick Test: Baseline" --scripted
echo -e "${GREEN}✓${NC} Baseline snapshot created"
echo ""

# Step 2: Install a package
echo -e "${BLUE}[2/5]${NC} Installing test package (htop)..."
apt-get update -qq
apt-get install -y htop > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Package installed"
echo ""

# Step 3: Create snapshot after installation
echo -e "${BLUE}[3/5]${NC} Creating snapshot after installation..."
sleep 2
linuxrollback --create --comments "Quick Test: After htop install" --scripted
echo -e "${GREEN}✓${NC} Post-install snapshot created"
echo ""

# Step 4: Show snapshots
echo -e "${BLUE}[4/5]${NC} Listing snapshots..."
echo ""
linuxrollback --list | head -10
echo ""

# Step 5: Check changes
echo -e "${BLUE}[5/5]${NC} Checking for changes..."
latest_snapshot=$(linuxrollback --list | grep "Quick Test: After" | head -1 | awk '{print $1}')

if [ -n "$latest_snapshot" ]; then
    snapshot_path="/timeshift/snapshots/$latest_snapshot"
    
    if [ -f "$snapshot_path/rsync-log-changes" ]; then
        change_count=$(wc -l < "$snapshot_path/rsync-log-changes")
        echo -e "${GREEN}✓${NC} Found $change_count file changes"
        echo ""
        echo "Sample changes:"
        head -10 "$snapshot_path/rsync-log-changes"
        echo ""
    else
        echo -e "${YELLOW}⚠${NC} rsync-log-changes not found"
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not find latest snapshot"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Test Complete!                                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Open LinuxRollback GUI: sudo linuxrollback-gtk"
echo "  2. Look at the 'Changes' column"
echo "  3. Right-click on 'Quick Test: After htop install'"
echo "  4. Select 'View Changes Details...'"
echo "  5. Browse the changes in different tabs"
echo ""
echo "To clean up:"
echo "  sudo ./cleanup-test-snapshots.sh"
echo ""
