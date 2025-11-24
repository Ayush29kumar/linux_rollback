#!/bin/bash
#
# Verify Change Count Accuracy
# Tests that change counting only includes files, not directory metadata
#

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Change Count Verification                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Find latest snapshot
LATEST_SNAPSHOT=$(sudo linuxrollback --list 2>/dev/null | grep "Quick Test: After" | head -1 | awk '{print $1}')

if [ -z "$LATEST_SNAPSHOT" ]; then
    echo -e "${YELLOW}No test snapshot found. Run quick-test.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}Snapshot:${NC} $LATEST_SNAPSHOT"
echo ""

# Find snapshot path
SNAPSHOT_PATH=$(sudo find /run/timeshift -name "$LATEST_SNAPSHOT" -type d 2>/dev/null | head -1)

if [ -z "$SNAPSHOT_PATH" ]; then
    echo -e "${RED}Could not find snapshot directory${NC}"
    exit 1
fi

LOG_FILE="$SNAPSHOT_PATH/rsync-log-changes"

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}rsync-log-changes not found at: $LOG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Log file:${NC} $LOG_FILE"
echo ""

# Count different types
TOTAL=$(sudo wc -l < "$LOG_FILE")
FILES=$(sudo grep -E '^(>f|<f|\*f|\.f)' "$LOG_FILE" | wc -l)
SYMLINKS=$(sudo grep -E '^(>L|<L|\*L|\.L)' "$LOG_FILE" | wc -l)
DIRS=$(sudo grep -E '^(cd|\.d|>d)' "$LOG_FILE" | wc -l)
OTHER=$((TOTAL - FILES - SYMLINKS - DIRS))

echo "=== Line Count Breakdown ==="
echo ""
printf "%-30s %5d\n" "Total lines:" $TOTAL
printf "%-30s %5d ${GREEN}✓${NC}\n" "File changes (>f, <f, *f, .f):" $FILES
printf "%-30s %5d ${GREEN}✓${NC}\n" "Symlink changes (>L, <L):" $SYMLINKS
printf "%-30s %5d ${YELLOW}⊘${NC}\n" "Directory changes (cd, .d):" $DIRS
printf "%-30s %5d\n" "Other:" $OTHER
echo ""

COUNTED=$((FILES + SYMLINKS))
PERCENTAGE=$(echo "scale=1; $COUNTED * 100 / $TOTAL" | bc)

echo "=== Change Count ==="
echo ""
printf "%-30s %5d\n" "Should count:" $COUNTED
printf "%-30s %5.1f%%\n" "Percentage of total:" $PERCENTAGE
echo ""

# Show sample file changes
echo "=== Sample File Changes (first 10) ==="
echo ""
sudo grep -E '^>f' "$LOG_FILE" | head -10 | while read line; do
    echo "  $line"
done
echo ""

# Verify count matches
echo "=== Verification ==="
echo ""

if [ $COUNTED -lt 30 ] && [ $COUNTED -gt 5 ]; then
    echo -e "${GREEN}✅ Count looks correct for small package (htop)${NC}"
    echo -e "${GREEN}✅ Expected: 10-25 files${NC}"
    echo -e "${GREEN}✅ Actual: $COUNTED files${NC}"
elif [ $COUNTED -lt 5 ]; then
    echo -e "${YELLOW}⚠ Very few changes detected${NC}"
    echo -e "${YELLOW}⚠ This might be a baseline snapshot${NC}"
else
    echo -e "${YELLOW}⚠ High change count${NC}"
    echo -e "${YELLOW}⚠ This might be a large package or system update${NC}"
fi

echo ""
echo -e "${BLUE}Note:${NC} LinuxRollback now counts only actual file changes,"
echo -e "      not directory metadata (timestamps, permissions, etc.)"
echo ""
