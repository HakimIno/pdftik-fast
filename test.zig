// test.zig
const std = @import("std");
const testing = std.testing;
const net = std.net;
const main = @import("src/main.zig");
const DefaultHtmlConverter = main.DefaultHtmlConverter;
const ws = @import("src/ws.zig");
const PdfOptions = main.PdfOptions;
const atomic = @import("std").atomic;

// Mock Stream implementation
const MockStream = struct {
    handle: i32,
    allocator: std.mem.Allocator,
    
    pub const ReadError = error{
        ConnectionClosed,
        ConnectionReset,
        ConnectionTimedOut,
        WouldBlock,
    };

    pub const WriteError = error{
        ConnectionFailed,
        ConnectionReset,
        ConnectionTimedOut,
        WouldBlock,
    };

    pub const Reader = std.io.Reader(*MockStream, ReadError, read);
    pub const Writer = std.io.Writer(*MockStream, WriteError, write);

    pub fn reader(self: *MockStream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *MockStream) Writer {
        return .{ .context = self };
    }
    
    pub fn init(allocator: std.mem.Allocator) !*MockStream {
        const self = try allocator.create(MockStream);
        self.* = .{
            .handle = -1,
            .allocator = allocator,
        };
        return self;
    }
    
    pub fn close(self: *MockStream) void {
        self.handle = -1;
    }
    
    pub fn write(_: *MockStream, _: []const u8) !usize {
        return error.ConnectionFailed;
    }
    
    pub fn read(self: *MockStream, buffer: []u8) !usize {
        _ = buffer;
        if (self.handle == -1) return error.ConnectionClosed;
        return 0;
    }

    pub fn deinit(self: *MockStream) void {
        self.allocator.destroy(self);
    }

    pub fn setNoDelay(self: *MockStream, _: bool) !void {
        _ = self;
    }

    pub fn setTcpNoDelay(self: *MockStream, _: bool) !void {
        _ = self;
    }

    pub fn getRemoteEndpoint(self: *MockStream) !net.Address {
        _ = self;
        return error.ConnectionFailed;
    }
};

// Mock WebSocket implementation
const MockWebSocket = struct {
    mock_stream: *MockStream,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*MockWebSocket {
        const self = try allocator.create(MockWebSocket);
        errdefer allocator.destroy(self);
        
        self.* = .{
            .mock_stream = try MockStream.init(allocator),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *MockWebSocket) void {
        self.mock_stream.deinit();
        self.allocator.destroy(self);
    }

    const vtable = ws.WebSocket.VTable{
        .sendFn = sendFn,
        .receiveFn = receiveFn,
        .deinitFn = deinitFn,
    };

    fn sendFn(ctx: *anyopaque, data: []const u8) !void {
        const self: *MockWebSocket = @ptrCast(@alignCast(ctx));
        _ = try self.mock_stream.write(data);
    }

    fn receiveFn(ctx: *anyopaque) ![]const u8 {
        _ = ctx;
        return error.ConnectionFailed;
    }

    fn deinitFn(ctx: *anyopaque) void {
        const self: *MockWebSocket = @ptrCast(@alignCast(ctx));
        self.deinit();
    }
};

// Test MockWebSocket functionality
test "MockWebSocket basic operations" {
    const allocator = std.testing.allocator;
    
    var mock = try MockWebSocket.init(allocator);
    defer mock.deinit();

    try std.testing.expect(mock.mock_stream.handle == -1);
    
    // Test write operation
    const write_result = mock.mock_stream.write("test");
    try std.testing.expectError(error.ConnectionFailed, write_result);
    
    // Test read operation
    var buf: [10]u8 = undefined;
    const read_result = mock.mock_stream.read(&buf);
    try std.testing.expectError(error.ConnectionClosed, read_result);
}

// Test WebSocket interface without real connection
test "WebSocket interface" {
    const allocator = std.testing.allocator;
    
    const mock_ws = try allocator.create(ws.WebSocket);
    defer allocator.destroy(mock_ws);
    
    mock_ws.* = .{
        .allocator = allocator,
        .stream = undefined,  // Don't initialize real stream
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = undefined,  // Don't initialize real vtable
        .ptr = undefined,
        .is_mock = true,
        .handle_state = atomic.Value(i32).init(0),
    };

    try std.testing.expect(!mock_ws.connected);
    try std.testing.expect(mock_ws.port == 9222);
    try std.testing.expect(std.mem.eql(u8, mock_ws.host, "localhost"));
}

test "DefaultHtmlConverter with MockWebSocket" {
    const allocator = std.testing.allocator;

    // สร้าง MockWebSocket โดยตรงแทนที่จะใช้ WebSocket.init
    var mock = try MockWebSocket.init(allocator);
    defer mock.deinit();

    // สร้าง WebSocket instance ที่ใช้ MockWebSocket
    var ws_instance = ws.WebSocket{
        .allocator = allocator,
        .stream = undefined,
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = @ptrCast(mock),
        .is_mock = true,
        .handle_state = atomic.Value(i32).init(-1),
    };

    // สร้าง converter พร้อม mock websocket
    var converter = main.DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = &ws_instance,
    };

    // HTML ตัวอย่าง
    const html =
        \\<html><body><h1>Test</h1></body></html>
    ;

    const options = PdfOptions{
        .landscape = false,
        .display_header_footer = false,
        .print_background = true,
        .scale = 1.0,
        .paper_width = 8.5,
        .paper_height = 11.0,
        .margin_top = 0.5,
        .margin_bottom = 0.5,
        .margin_left = 0.5,
        .margin_right = 0.5,
        .header_template = "",
        .footer_template = "",
    };

    // ทดสอบการแปลง HTML เป็น PDF
    const result = converter.htmlToPdf(html, options);
    try std.testing.expectError(error.ConnectionFailed, result);
}
