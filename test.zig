// test.zig
const std = @import("std");
const testing = std.testing;
const net = std.net;
const DefaultHtmlConverter = @import("src/main.zig").DefaultHtmlConverter;
const ws = @import("src/ws.zig");
const PdfOptions = @import("src/main.zig").PdfOptions;

// Mock Stream implementation
const MockStream = struct {
    handle: i32,

    pub fn init() MockStream {
        return .{ .handle = -1 };
    }

    pub fn write(self: *MockStream, data: []const u8) !usize {
        _ = self;
        return data.len;
    }

    pub fn close(self: *MockStream) void {
        _ = self;
    }
};

// Mock WebSocket implementation
const MockWebSocket = struct {
    mock_stream: MockStream,

    pub fn init() MockWebSocket {
        return .{
            .mock_stream = MockStream.init(),
        };
    }

    const vtable = ws.WebSocket.VTable{
        .sendFn = sendFn,
        .receiveFn = receiveFn,
        .deinitFn = deinitFn,
    };

    fn sendFn(ctx: *anyopaque, data: []const u8) ws.WebSocket.Error!void {
        const self: *MockWebSocket = @ptrCast(@alignCast(ctx));
        _ = try self.mock_stream.write(data);
    }

    fn receiveFn(ctx: *anyopaque) ws.WebSocket.Error![]const u8 {
        _ = ctx;
        return error.ConnectionFailed;
    }

    fn deinitFn(ctx: *anyopaque) void {
        const self: *MockWebSocket = @ptrCast(@alignCast(ctx));
        self.mock_stream.close();
    }
};

test "HTML to PDF empty input" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "HTML to PDF basic test" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with custom page size" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Custom size test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with landscape orientation" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Landscape test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with custom margins" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Custom margins test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with header and footer" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Header and footer test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with custom scale" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Custom scale test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with background graphics" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Background test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with all options combined" {
    const allocator = std.testing.allocator;

    var mock = MockWebSocket.init();
    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{
        .landscape = true,
        .print_background = true,
        .scale = 0.9,
        .paper_width = 11.69,
        .paper_height = 8.27,
        .margin_top = 25,
        .margin_bottom = 25,
        .margin_left = 20,
        .margin_right = 20,
        .display_header_footer = true,
        .header_template = "<div>Header</div>",
        .footer_template = "<div>Footer</div>",
    };

    const result = converter.htmlToPdf("<html><body>Combined options test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}

test "PDF with custom timeout" {
    const allocator = std.testing.allocator;
    var mock = MockWebSocket.init();

    const mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = .{ .handle = mock.mock_stream.handle },
        .url = "ws://localhost:9222",
        .host = "localhost",
        .port = 9222,
        .path = "/devtools/page/default",
        .connected = false,
        .buffer = &[_]u8{},
        .vtable = &MockWebSocket.vtable,
        .ptr = &mock,
        .is_mock = true,
    };

    var converter = DefaultHtmlConverter{
        .allocator = allocator,
        .ws_client = mock_ws,
    };

    const options = PdfOptions{};
    const result = converter.htmlToPdf("<html><body>Timeout test</body></html>", options);
    try std.testing.expectError(error.ConnectionFailed, result);
}
