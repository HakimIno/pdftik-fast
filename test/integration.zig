test "Real Chrome integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to real Chrome instance
    var ws_client = try ws.WebSocket.init(allocator, "ws://localhost:9222/devtools/page/XXX");
    defer ws_client.deinit();

    var converter = try DefaultHtmlConverter.init(allocator, ws_client);
    defer converter.deinit();

    // Test real PDF conversion
    const html = "<html><body>Integration test</body></html>";
    const options = PdfOptions{
        .landscape = true,
        .print_background = true,
    };

    const pdf_data = try converter.htmlToPdf(html, options);
    defer allocator.free(pdf_data);

    // Save PDF for manual inspection
    const file = try std.fs.cwd().createFile("test.pdf", .{});
    defer file.close();
    try file.writeAll(pdf_data);
}
