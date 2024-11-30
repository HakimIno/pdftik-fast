const std = @import("std");
const ws = @import("ws.zig");

pub const PdfOptions = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    landscape: bool = false,
    display_header_footer: bool = false,
    print_background: bool = false,
    scale: f64 = 1.0,
    paper_width: f64 = 8.5, // A4 default
    paper_height: f64 = 11.0, // A4 default
    margin_top: f64 = 0.0,
    margin_bottom: f64 = 0.0,
    margin_left: f64 = 0.0,
    margin_right: f64 = 0.0,
    page_size: ?[]const u8 = null,
    header_template: ?[]const u8 = null,
    footer_template: ?[]const u8 = null,
};

const ChromeTarget = struct {
    description: []const u8,
    devtoolsFrontendUrl: []const u8,
    id: []const u8,
    title: []const u8,
    type: []const u8,
    url: []const u8,
    webSocketDebuggerUrl: []const u8,
    faviconUrl: ?[]const u8 = null,
    parentId: ?[]const u8 = null,
};

pub fn connectToChrome(allocator: std.mem.Allocator) !*ws.WebSocket {
    var client = std.http.Client{
        .allocator = allocator,
    };
    defer client.deinit();

    var buffer: [1024]u8 = undefined;
    var req = try client.open(.GET, try std.Uri.parse("http://localhost:9222/json/list"), .{
        .server_header_buffer = buffer[0..],
    });
    defer req.deinit();
    try req.send();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 10_000);
    defer allocator.free(body);

    std.debug.print("Response body: {s}\n", .{body});

    const parsed = try std.json.parseFromSlice(
        []ChromeTarget,
        allocator,
        body,
        .{ .ignore_unknown_fields = true }
    );
    defer parsed.deinit();

    const websocket = try ws.WebSocket.init(allocator, parsed.value[0].webSocketDebuggerUrl);
    return websocket;
}

pub const DefaultHtmlConverter = struct {
    allocator: std.mem.Allocator,
    ws_client: *ws.WebSocket,

    pub fn init(allocator: std.mem.Allocator) !*DefaultHtmlConverter {
        var ws_client = try connectToChrome(allocator);
        errdefer ws_client.deinit();

        const self = try allocator.create(DefaultHtmlConverter);
        self.* = .{
            .allocator = allocator,
            .ws_client = ws_client,
        };
        return self;
    }

    pub fn deinit(self: *DefaultHtmlConverter) void {
        self.ws_client.deinit();
        self.allocator.destroy(self);
    }

    pub fn htmlToPdf(self: *DefaultHtmlConverter, html: []const u8, options: PdfOptions) ![]u8 {
        var navigate_list = std.ArrayList(u8).init(self.allocator);
        defer navigate_list.deinit();
        
        try std.json.stringify(.{
            .id = 1,
            .method = "Page.navigate",
            .params = .{
                .url = "about:blank",
            },
        }, .{}, navigate_list.writer());
        
        try self.ws_client.vtable.sendFn(self.ws_client.ptr, navigate_list.items);
        _ = try self.ws_client.vtable.receiveFn(self.ws_client.ptr);

        // Set HTML content
        var content_list = std.ArrayList(u8).init(self.allocator);
        defer content_list.deinit();
        
        try std.json.stringify(.{
            .id = 2,
            .method = "Page.setDocumentContent",
            .params = .{
                .html = html,
            },
        }, .{}, content_list.writer());
        
        try self.ws_client.vtable.sendFn(self.ws_client.ptr, content_list.items);
        _ = try self.ws_client.vtable.receiveFn(self.ws_client.ptr);

        // Generate PDF
        var print_list = std.ArrayList(u8).init(self.allocator);
        defer print_list.deinit();
        
        try std.json.stringify(.{
            .id = 3,
            .method = "Page.printToPDF",
            .params = .{
                .landscape = options.landscape,
                .displayHeaderFooter = options.display_header_footer,
                .printBackground = options.print_background,
                .scale = options.scale,
                .paperWidth = options.paper_width,
                .paperHeight = options.paper_height,
                .marginTop = options.margin_top,
                .marginBottom = options.margin_bottom,
                .marginLeft = options.margin_left,
                .marginRight = options.margin_right,
                .headerTemplate = options.header_template,
                .footerTemplate = options.footer_template,
            },
        }, .{}, print_list.writer());
        
        try self.ws_client.vtable.sendFn(self.ws_client.ptr, print_list.items);
        const response = try self.ws_client.vtable.receiveFn(self.ws_client.ptr);

        // Parse response to get PDF data
        const parsed = try std.json.parseFromSlice(
            struct {
                id: i32,
                result: struct {
                    data: []const u8,
                },
            },
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        // Decode base64 PDF data
        const pdf_base64 = parsed.value.result.data;
        const decoded_len = try std.base64.standard.Decoder.calcSizeForSlice(pdf_base64);
        const decoded = try self.allocator.alloc(u8, decoded_len);
        _ = try std.base64.standard.Decoder.decode(decoded, pdf_base64);

        return decoded;
    }

    // เพิ่มฟังก์ชันสำหรับ testing
    pub fn initWithWebSocket(allocator: std.mem.Allocator, mock_ws: *ws.WebSocket) !DefaultHtmlConverter {
        return .{
            .allocator = allocator,
            .ws_client = mock_ws,
        };
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const html = "<html><body>Hello</body></html>";

    var converter = try DefaultHtmlConverter.init(allocator);
    defer converter.deinit();

    const options = PdfOptions{};
    const result = try converter.htmlToPdf(html, options);
    _ = result;
}