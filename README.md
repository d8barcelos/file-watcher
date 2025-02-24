# Zig File Watcher

A high-performance file system monitoring utility written in Zig that provides real-time notifications for file system changes. This tool implements smart polling with checksums to accurately detect file modifications, creations, and deletions.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Zig](https://img.shields.io/badge/zig-%3E%3D0.11.0-orange.svg)

## Features

- **Accurate Change Detection**
  - File modification tracking using timestamps
  - Content change detection via checksums
  - File size monitoring
  - Deletion detection
  
- **Smart Performance**
  - Configurable polling intervals
  - Efficient resource usage
  - Optimized checksum calculation
  - Memory-conscious design

- **Rich Output Options**
  - Color-coded event types
  - Configurable timestamp display
  - Quiet mode for reduced output
  - Detailed initial configuration display

- **Flexible Configuration**
  - Command-line argument support
  - Configurable ignore patterns
  - Adjustable polling frequency
  - Multiple output formats

## Installation

1. Ensure you have Zig ≥0.11.0 installed:
   ```bash
   zig version
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/zig-file-watcher.git
   cd zig-file-watcher
   ```

3. Build the project:
   ```bash
   zig build-exe src/file_watcher.zig -O ReleaseFast
   ```

## Usage

### Basic Usage

Monitor a directory with default settings:
```bash
./file_watcher /path/to/watch
```

### Command-line Options

```bash
./file_watcher [options] <directory>

Options:
  -i, --interval <ms>    Set polling interval in milliseconds (default: 1000)
  -r, --recursive        Watch subdirectories recursively
  -q, --quiet           Suppress modification events
  -t, --no-timestamps   Don't show timestamps in output
  -h, --help            Display this help message
```

### Example Commands

```bash
# Watch with 500ms polling interval
./file_watcher -i 500 /path/to/watch

# Watch in quiet mode (only show creation/deletion events)
./file_watcher -q /path/to/watch

# Watch without timestamp display
./file_watcher -t /path/to/watch

# Watch with multiple options
./file_watcher -i 200 -q -t /path/to/watch
```

## Output Format

The watcher provides color-coded output for different event types:

- 🟢 **Green**: File created
- 🟡 **Yellow**: File modified
- 🔴 **Red**: File deleted

Example output:
```
[2024-02-24 15:30:45] [CREATED] example.txt
[2024-02-24 15:30:48] [MODIFIED] example.txt
[2024-02-24 15:31:02] [DELETED] old_file.txt
```

## Technical Details

### Change Detection Mechanism

The file watcher uses multiple methods to detect changes:

1. **Modification Time**
   - Tracks file modification timestamps
   - Provides basic change detection

2. **File Size**
   - Monitors changes in file size
   - Catches content modifications

3. **Content Checksums**
   - Calculates efficient file checksums
   - Detects content changes even when timestamps remain unchanged

### Performance Considerations

The watcher implements several optimizations:

- Efficient buffer sizes for file reading
- Optimized checksum algorithm
- Memory-conscious data structures
- Configurable polling intervals

## Configuration Structure

```zig
const WatcherConfig = struct {
    poll_interval: u64 = 1000,  // milliseconds
    recursive: bool = false,
    ignore_patterns: []const []const u8 = &.{},
    quiet_mode: bool = false,
    show_timestamps: bool = true,
};
```

## Development

### Building from Source

1. **Debug Build**:
   ```bash
   zig build-exe src/file_watcher.zig -O Debug
   ```

2. **Release Build**:
   ```bash
   zig build-exe src/file_watcher.zig -O ReleaseFast
   ```

### Running Tests

```bash
zig test src/file_watcher.zig
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Error Handling

The watcher implements robust error handling for common scenarios:

- Invalid directory paths
- Permission issues
- File access errors
- Resource allocation failures

## Known Limitations

- Polling-based approach may miss very rapid changes
- No direct support for file system events (uses polling)
- Recursive watching is structure-ready but needs implementation
- Large files may impact checksum calculation time

## Future Improvements

- [ ] Implement recursive directory watching
- [ ] Add support for custom event handlers
- [ ] Implement file pattern matching
- [ ] Add configuration file support
- [ ] Improve performance for large directories

## Acknowledgments

- Inspired by various file watching utilities
- Built with the Zig programming language
- Thanks to all contributors

## Support

For support, please:
- Open an issue in the GitHub repository
- Check existing documentation
- Join our community discussions

---

**Note**: This project is under active development. Contributions and feedback are welcome!