#!/bin/bash
#
# LinuxRollback Snapshot Changes Cleanup Script
# Removes all test snapshots and packages installed during testing
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run with sudo"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║   LinuxRollback Test Cleanup Script                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Remove test snapshots
print_info "Removing test snapshots..."

# Get list of test snapshots
test_snapshots=$(sudo linuxrollback --list | grep "Test [0-9]:" | awk '{print $1}' || echo "")

if [ -z "$test_snapshots" ]; then
    print_info "No test snapshots found"
else
    snapshot_count=$(echo "$test_snapshots" | wc -l)
    print_info "Found $snapshot_count test snapshot(s)"
    
    echo "$test_snapshots" | while read snapshot; do
        if [ -n "$snapshot" ]; then
            print_info "Deleting snapshot: $snapshot"
            if sudo linuxrollback --delete --snapshot "$snapshot"; then
                print_success "Deleted: $snapshot"
            else
                print_error "Failed to delete: $snapshot"
            fi
        fi
    done
fi

# Remove test packages
print_info "Removing test packages..."

packages_to_remove=("htop" "gimp" "curl")

for package in "${packages_to_remove[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        print_info "Removing package: $package"
        if apt-get remove -y "$package"; then
            print_success "Removed: $package"
        else
            print_warning "Failed to remove: $package"
        fi
    else
        print_info "Package not installed: $package"
    fi
done

# Clean up apt cache
print_info "Cleaning apt cache..."
apt-get autoremove -y
apt-get clean

# Remove test files
print_info "Removing test files..."

test_files=(
    "/usr/local/bin/test-script"
    "/usr/local/share/test-app/data.txt"
    "/usr/local/share/test-app"
    "/usr/local/test.txt"
)

for file in "${test_files[@]}"; do
    if [ -e "$file" ]; then
        print_info "Removing: $file"
        rm -rf "$file"
        print_success "Removed: $file"
    fi
done

# Restore config files if backups exist
print_info "Checking for config backups..."

if [ -f "/tmp/hostname.bak" ]; then
    print_info "Restoring /etc/hostname"
    mv /tmp/hostname.bak /etc/hostname
    print_success "Restored /etc/hostname"
fi

if [ -f "/tmp/hosts.bak" ]; then
    print_info "Restoring /etc/hosts"
    mv /tmp/hosts.bak /etc/hosts
    print_success "Restored /etc/hosts"
fi

# Remove test directory
if [ -d "/tmp/linuxrollback-test" ]; then
    print_info "Removing test directory..."
    rm -rf "/tmp/linuxrollback-test"
    print_success "Test directory removed"
fi

echo ""
print_success "Cleanup complete!"
echo ""
print_info "Summary:"
echo "  - Test snapshots deleted"
echo "  - Test packages removed"
echo "  - Test files cleaned up"
echo "  - Config files restored"
echo ""
