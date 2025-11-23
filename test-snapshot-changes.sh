#!/bin/bash
#
# LinuxRollback Snapshot Changes Test Suite
# This script tests the snapshot diff/changes feature
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="/tmp/linuxrollback-test"
LOG_FILE="$TEST_DIR/test-results.log"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to create snapshot
create_snapshot() {
    local comment="$1"
    print_info "Creating snapshot: $comment"
    
    if sudo linuxrollback --create --comments "$comment" --scripted; then
        print_success "Snapshot created successfully"
        return 0
    else
        print_error "Failed to create snapshot"
        return 1
    fi
}

# Function to get latest snapshot name
get_latest_snapshot() {
    sudo linuxrollback --list | grep -v "^Device" | grep -v "^---" | head -1 | awk '{print $1}'
}

# Function to check snapshot changes
check_snapshot_changes() {
    local snapshot_name="$1"
    local expected_min_changes="$2"
    
    print_info "Checking changes in snapshot: $snapshot_name"
    
    # Get snapshot info (this would need to parse the actual snapshot data)
    # For now, we'll check if the rsync-log-changes file exists
    local snapshot_path="/timeshift/snapshots/$snapshot_name"
    
    if [ -f "$snapshot_path/rsync-log-changes" ]; then
        local change_count=$(wc -l < "$snapshot_path/rsync-log-changes")
        print_info "Found $change_count changes in snapshot"
        
        if [ "$change_count" -ge "$expected_min_changes" ]; then
            print_success "Change count ($change_count) meets minimum ($expected_min_changes)"
            return 0
        else
            print_error "Change count ($change_count) below minimum ($expected_min_changes)"
            return 1
        fi
    else
        print_error "rsync-log-changes file not found"
        return 1
    fi
}

# Initialize test environment
init_test() {
    print_info "Initializing test environment..."
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Clear log file
    > "$LOG_FILE"
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo"
        exit 1
    fi
    
    # Check if linuxrollback is installed
    if ! command -v linuxrollback &> /dev/null; then
        print_error "linuxrollback command not found"
        exit 1
    fi
    
    print_success "Test environment initialized"
}

# Test Case 1: Baseline snapshot (minimal changes)
test_baseline() {
    print_info "========================================="
    print_info "TEST 1: Baseline Snapshot"
    print_info "========================================="
    
    create_snapshot "Test 1: Baseline"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # Baseline should have minimal changes (0-10)
    if check_snapshot_changes "$snapshot" 0; then
        print_success "TEST 1: PASSED"
        return 0
    else
        print_error "TEST 1: FAILED"
        return 1
    fi
}

# Test Case 2: Small package installation
test_small_package() {
    print_info "========================================="
    print_info "TEST 2: Small Package Installation"
    print_info "========================================="
    
    print_info "Installing htop..."
    apt-get update -qq
    apt-get install -y htop
    
    sleep 2
    create_snapshot "Test 2: After htop install"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # htop should add at least 5 files
    if check_snapshot_changes "$snapshot" 5; then
        print_success "TEST 2: PASSED"
        return 0
    else
        print_error "TEST 2: FAILED"
        return 1
    fi
}

# Test Case 3: Configuration file changes
test_config_changes() {
    print_info "========================================="
    print_info "TEST 3: Configuration File Changes"
    print_info "========================================="
    
    # Modify some config files
    print_info "Modifying configuration files..."
    
    # Backup original files
    cp /etc/hostname /tmp/hostname.bak
    cp /etc/hosts /tmp/hosts.bak
    
    # Make changes
    echo "test-hostname" > /etc/hostname
    echo "127.0.0.1 test-host" >> /etc/hosts
    
    sleep 2
    create_snapshot "Test 3: After config changes"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # Should detect at least 2 changed files
    if check_snapshot_changes "$snapshot" 2; then
        print_success "TEST 3: PASSED"
    else
        print_error "TEST 3: FAILED"
    fi
    
    # Restore original files
    mv /tmp/hostname.bak /etc/hostname
    mv /tmp/hosts.bak /etc/hosts
}

# Test Case 4: Large package installation
test_large_package() {
    print_info "========================================="
    print_info "TEST 4: Large Package Installation"
    print_info "========================================="
    
    print_info "Installing gimp (large package)..."
    apt-get install -y gimp
    
    sleep 2
    create_snapshot "Test 4: After gimp install"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # GIMP should add 100+ files
    if check_snapshot_changes "$snapshot" 100; then
        print_success "TEST 4: PASSED"
        return 0
    else
        print_error "TEST 4: FAILED"
        return 1
    fi
}

# Test Case 5: File creation in /usr/local
test_custom_files() {
    print_info "========================================="
    print_info "TEST 5: Custom File Creation"
    print_info "========================================="
    
    print_info "Creating custom files..."
    
    # Create test files
    echo "#!/bin/bash" > /usr/local/bin/test-script
    echo "echo 'Test script'" >> /usr/local/bin/test-script
    chmod +x /usr/local/bin/test-script
    
    mkdir -p /usr/local/share/test-app
    echo "Test data" > /usr/local/share/test-app/data.txt
    
    sleep 2
    create_snapshot "Test 5: After custom files"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # Should detect at least 2 new files
    if check_snapshot_changes "$snapshot" 2; then
        print_success "TEST 5: PASSED"
        return 0
    else
        print_error "TEST 5: FAILED"
        return 1
    fi
}

# Test Case 6: Multiple changes (mixed)
test_mixed_changes() {
    print_info "========================================="
    print_info "TEST 6: Mixed Changes"
    print_info "========================================="
    
    print_info "Making multiple types of changes..."
    
    # Install package
    apt-get install -y curl
    
    # Modify config
    echo "# Test comment" >> /etc/bash.bashrc
    
    # Create file
    echo "Test" > /usr/local/test.txt
    
    sleep 2
    create_snapshot "Test 6: Mixed changes"
    
    local snapshot=$(get_latest_snapshot)
    print_info "Latest snapshot: $snapshot"
    
    # Should detect at least 10 changes
    if check_snapshot_changes "$snapshot" 10; then
        print_success "TEST 6: PASSED"
        return 0
    else
        print_error "TEST 6: FAILED"
        return 1
    fi
}

# Generate test report
generate_report() {
    print_info "========================================="
    print_info "TEST REPORT"
    print_info "========================================="
    
    echo ""
    echo "Test Results Summary:" | tee -a "$LOG_FILE"
    echo "--------------------" | tee -a "$LOG_FILE"
    
    local total_tests=6
    local passed_tests=$(grep -c "PASSED" "$LOG_FILE" || echo "0")
    local failed_tests=$(grep -c "FAILED" "$LOG_FILE" || echo "0")
    
    echo "Total Tests: $total_tests" | tee -a "$LOG_FILE"
    echo "Passed: $passed_tests" | tee -a "$LOG_FILE"
    echo "Failed: $failed_tests" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    if [ "$failed_tests" -eq 0 ]; then
        print_success "ALL TESTS PASSED!"
    else
        print_error "SOME TESTS FAILED!"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    echo "Full log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # List all snapshots created
    print_info "Snapshots created during testing:"
    sudo linuxrollback --list | grep "Test [0-9]:" || echo "No test snapshots found"
}

# Main test execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   LinuxRollback Snapshot Changes Test Suite           ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    init_test
    
    # Run all tests
    test_baseline
    test_small_package
    test_config_changes
    test_large_package
    test_custom_files
    test_mixed_changes
    
    # Generate report
    generate_report
    
    print_info "Testing complete!"
    print_warning "Remember to run cleanup script to remove test snapshots and packages"
}

# Run main function
main "$@"
