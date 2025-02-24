const std = @import("std");

// Configuration structure for the file watcher
const WatcherConfig = struct {
    poll_interval: u64 = 1000, // milliseconds
    recursive: bool = false,
    ignore_patterns: []const []const u8 = &.{},
    quiet_mode: bool = false,
    show_timestamps: bool = true,
};

// Event types for file changes
const EventType = enum {
    Created,
    Modified,
    Deleted,
};

// Structure to hold file information
const FileInfo = struct {
    mod_time: std.time.Time,
    size: u64,
    checksum: u64,
};

// Color codes for output
const Colors = struct {
    const reset = "\x1b[0m";
    const green = "\x1b[32m";
    const yellow = "\x1b[33m";
    const red = "\x1b[31m";
    const blue = "\x1b[34m";
};

/// Checks if a file matches any of the ignore patterns
fn shouldIgnoreFile(file_name: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| {
        if (std.mem.indexOf(u8, file_name, pattern) != null) {
            return true;
        }
    }
    return false;
}

/// Calculates a simple checksum of a file
fn calculateChecksum(file_path: []const u8) !u64 {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var hash: u64 = 0;
    var buffer: [8192]u8 = undefined;
    
    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;
        
        for (buffer[0..bytes_read]) |byte| {
            hash = (hash *% 31 +% @as(u64, byte));
        }
    }
    
    return hash;
}

/// Formats the current timestamp
fn getTimestamp() ![64]u8 {
    var buffer: [64]u8 = undefined;
    const timestamp = std.time.timestamp();
    const datetime = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
    return std.fmt.bufPrint(&buffer, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        datetime.getEpochDay().calculateYearDay().year,
        datetime.getEpochDay().calculateYearDay().month,
        datetime.getEpochDay().calculateYearDay().day_of_month,
        datetime.getDaySeconds().getHourOfDay(),
        datetime.getDaySeconds().getMinuteOfHour(),
        datetime.getDaySeconds().getSecondOfMinute(),
    });
}

/// Prints a formatted event message
fn printEvent(event_type: EventType, file_name: []const u8, config: WatcherConfig, writer: anytype) !void {
    if (config.quiet_mode and event_type == .Modified) return;

    const color = switch (event_type) {
        .Created => Colors.green,
        .Modified => Colors.yellow,
        .Deleted => Colors.red,
    };

    const event_str = switch (event_type) {
        .Created => "CREATED",
        .Modified => "MODIFIED",
        .Deleted => "DELETED",
    };

    if (config.show_timestamps) {
        const timestamp = try getTimestamp();
        try writer.print("{s}[{s}] {s}[{s}]{s} {s}\n", .{
            Colors.blue, timestamp, color, event_str, Colors.reset, file_name,
        });
    } else {
        try writer.print("{s}[{s}]{s} {s}\n", .{
            color, event_str, Colors.reset, file_name,
        });
    }
}

/// Watches a directory for changes
fn watchDirectory(dir_path: []const u8, config: WatcherConfig, allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    // Create a hash map to store file information
    var file_info = std.StringHashMap(FileInfo).init(allocator);
    defer file_info.deinit();

    try stdout.print("Starting file watcher on: {s}\n", .{dir_path});
    try stdout.print("Configuration:\n", .{});
    try stdout.print("  Poll interval: {}ms\n", .{config.poll_interval});
    try stdout.print("  Recursive: {}\n", .{config.recursive});
    try stdout.print("  Quiet mode: {}\n", .{config.quiet_mode});
    try stdout.print("  Show timestamps: {}\n", .{config.show_timestamps});
    if (config.ignore_patterns.len > 0) {
        try stdout.print("  Ignore patterns: {any}\n", .{config.ignore_patterns});
    }
    try stdout.print("\n", .{});

    // Main polling loop
    while (true) {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var seen_files = std.StringHashMap(void).init(allocator);
        defer seen_files.deinit();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .File) continue;
            if (shouldIgnoreFile(entry.name, config.ignore_patterns)) continue;

            // Build full file path
            const file_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
            defer allocator.free(file_path);

            try seen_files.put(try allocator.dupe(u8, entry.name), {});

            // Get file metadata and calculate checksum
            const meta = try std.fs.metadata(file_path);
            const current_info = FileInfo{
                .mod_time = meta.modified,
                .size = meta.size,
                .checksum = try calculateChecksum(file_path),
            };

            // Check for file changes
            if (file_info.get(entry.name)) |prev_info| {
                if (current_info.mod_time != prev_info.mod_time or
                    current_info.size != prev_info.size or
                    current_info.checksum != prev_info.checksum)
                {
                    try printEvent(.Modified, entry.name, config, stdout);
                    try file_info.put(try allocator.dupe(u8, entry.name), current_info);
                }
            } else {
                try printEvent(.Created, entry.name, config, stdout);
                try file_info.put(try allocator.dupe(u8, entry.name), current_info);
            }
        }

        // Check for deleted files
        var file_it = file_info.iterator();
        while (file_it.next()) |kv| {
            if (!seen_files.contains(kv.key_ptr.*)) {
                try printEvent(.Deleted, kv.key_ptr.*, config, stdout);
                _ = file_info.remove(kv.key_ptr.*);
            }
        }

        try stdout.flush();
        std.time.sleep(config.poll_interval * std.time.ns_per_ms);
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command-line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.next();

    // Default configuration
    var config = WatcherConfig{};
    var dir_path: ?[]const u8 = null;

    // Process command-line arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            const stdout = std.io.getStdOut().writer();
            try stdout.print(
                \\Usage: {} [options] <directory>
                \\
                \\Options:
                \\  -i, --interval <ms>    Set polling interval in milliseconds (default: 1000)
                \\  -r, --recursive        Watch subdirectories recursively
                \\  -q, --quiet           Suppress modification events
                \\  -t, --no-timestamps   Don't show timestamps in output
                \\  -h, --help            Display this help message
                \\
                , .{args.inner.arg0},
            );
            return;
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interval")) {
            if (args.next()) |interval_str| {
                config.poll_interval = try std.fmt.parseInt(u64, interval_str, 10);
            }
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--recursive")) {
            config.recursive = true;
        } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
            config.quiet_mode = true;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--no-timestamps")) {
            config.show_timestamps = false;
        } else if (dir_path == null) {
            dir_path = arg;
        }
    }

    if (dir_path == null) {
        std.debug.print("Error: No directory specified\n", .{});
        return error.MissingDirectory;
    }

    try watchDirectory(dir_path.?, config, allocator);
}