const std = @import("std");
const main = @import("main");
const ws = @import("ws");
const testing = std.testing;

test "DefaultHtmlConverter basic operations" {
    const allocator = testing.allocator;
    
    var mock_ws = ws.WebSocket{
        .allocator = allocator,
        .stream = undefined,
        .url = "ws://test",
        .host = "test",
        .port = 9222,
        .path = "/test",
        .connected = true,
        .buffer = &[_]u8{},
        .vtable = undefined,
        .ptr = undefined,
        .is_mock = true,
        .handle_state = std.atomic.Value(i32).init(0),
    };

    var converter = try main.DefaultHtmlConverter.initWithWebSocket(
        allocator,
        &mock_ws
    );
    defer converter.deinit();

    const html = "<html><body>Test</body></html>";
    const options = main.PdfOptions{};
    
    const result = converter.htmlToPdf(html, options);
    try testing.expectError(error.ConnectionFailed, result);
} 