// src/main.zig
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

pub const DefaultHtmlConverter = struct {
    allocator: std.mem.Allocator,
    ws_client: ws.WebSocket,

    pub fn init(allocator: std.mem.Allocator, ws_client: ws.WebSocket) !*DefaultHtmlConverter {
        const self = try allocator.create(DefaultHtmlConverter);
        self.* = .{
            .allocator = allocator,
            .ws_client = ws_client,
        };
        return self;
    }

    pub fn deinit(self: *DefaultHtmlConverter) void {
        self.allocator.destroy(self);
    }

    pub fn htmlToPdf(self: *DefaultHtmlConverter, html: []const u8, options: PdfOptions) ![]u8 {
        _ = self;
        _ = html;
        _ = options;
        return error.ConnectionFailed;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const html = "<html><body>Hello</body></html>";

    // TODO: สร้าง WebSocket connection จริง
    var converter = try DefaultHtmlConverter.init(allocator, undefined);
    defer converter.deinit();

    const options = PdfOptions{};
    const result = try converter.htmlToPdf(html, options);
    _ = result;
    // TODO: บันทึก PDF
}
