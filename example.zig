const std = @import("std");
const ChildProcess = std.process.Child;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get current working directory
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.process.getCwd(&buf);

    // สร้าง absolute path สำหรับ HTML file
    const html_path = try std.fmt.allocPrint(
        allocator,
        "file://{s}/products.html",
        .{cwd}
    );
    defer allocator.free(html_path);

    // สร้าง arguments สำหรับ Chrome
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    try args.append("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome");
    try args.append("--headless");
    try args.append("--disable-gpu");
    try args.append("--print-to-pdf=output.pdf");
    try args.append(html_path);

    std.debug.print("Converting HTML to PDF...\n", .{});
    std.debug.print("HTML path: {s}\n", .{html_path});

    // สร้าง child process
    var process = ChildProcess.init(args.items, allocator);
    process.stderr_behavior = .Pipe;
    process.stdout_behavior = .Pipe;

    // รัน process
    try process.spawn();

    // รอให้ทำงานเสร็จ
    const term = try process.wait();

    if (term != .Exited or term.Exited != 0) {
        if (process.stderr) |stderr| {
            const err_msg = try stderr.reader().readAllAlloc(allocator, 1024);
            defer allocator.free(err_msg);
            std.debug.print("Error: {s}\n", .{err_msg});
        }
        return error.ChromeError;
    }

    std.debug.print("PDF created successfully at: output.pdf\n", .{});
}