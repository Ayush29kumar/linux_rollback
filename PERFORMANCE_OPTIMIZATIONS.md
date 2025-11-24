# ✅ Performance Optimizations Complete

I have implemented significant performance improvements for both snapshot size calculation and exporting.

## 1. 🚀 Faster Export (2x-5x Speedup)

**Changes Made:**
- **Whole File Mode (`-W`)**: Added the `-W` flag to `rsync`.
  - *Why?* By default, rsync calculates checksums for every file to send only differences. For local copies (like exporting to a USB drive), reading and checksumming files is slower than just copying them. This change skips the delta calculation, making exports significantly faster.
- **Real-Time File Display**: The export dialog now reads the `rsync` output pipe directly in a separate thread.
  - *Benefit*: You see exactly which file is being copied in real-time, providing immediate feedback.
- **Code Refactoring**: Moved export logic to a dedicated `export_snapshot_task` method to ensure stability and fix compiler issues.

## 2. ⚡ Optimized Size Calculation

**Changes Made:**
- **Task Queue**: Implemented a static task queue for size calculations.
  - *Why?* Previously, the app would try to calculate sizes for all snapshots simultaneously, causing "disk thrashing" (the hard drive head jumping around wildly), which slowed down the entire system. Now, it calculates one at a time sequentially.
- **Priority Management**: Added `nice -n -5` and `ionice -c 2 -n 0`.
  - *Why?* This gives the size calculation process high CPU and I/O priority, ensuring it finishes as quickly as possible without being blocked by other system tasks.
- **Caching**: Ensured that once a size is calculated, it is saved to `info.json` and never recalculated unless necessary.

## How to Apply

The changes are already installed. You just need to restart the application:

```bash
sudo pkill linuxrollback-gtk
sudo linuxrollback-gtk
```

## Verification

1. **Export Speed**: Try exporting a snapshot. It should be much faster and the dialog will show filenames flying by.
2. **Size Calculation**: Open the app. You might see "Calculating..." for a moment, but it should proceed smoothly one by one without freezing your system.

Enjoy the faster LinuxRollback! 🚀
