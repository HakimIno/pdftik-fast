const std = @import("std");
const pdftik = @import("pdftik-fast");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize converter
    var ws_client = try pdftik.ws.WebSocket.init(allocator, "ws://localhost:9222/devtools/page/XXX");
    defer ws_client.deinit();

    var converter = try pdftik.DefaultHtmlConverter.init(allocator, ws_client);
    defer converter.deinit();

    // Convert HTML to PDF
    const html = "<html><body>Hello, PDF!</body></html>";
    const options = pdftik.PdfOptions{
        .landscape = true,
        .print_background = true,
    };

    const pdf_data = try converter.htmlToPdf(html, options);
    defer allocator.free(pdf_data);

    // Save PDF
    const file = try std.fs.cwd().createFile("output.pdf", .{});
    defer file.close();
    try file.writeAll(pdf_data);
}
