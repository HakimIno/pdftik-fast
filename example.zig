const std = @import("std");
const lib = @import("src/main.zig");
const ws = @import("src/ws.zig");
const base64 = std.base64;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ws_client = try ws.WebSocket.init(
        allocator,
        "ws://localhost:9222/devtools/page/46E726C80917B2FDDE01383F44BC9B11"
    );
    defer ws_client.deinit();

    // 1. Navigate to URL
    const navigate_command = "{\"id\":1,\"method\":\"Page.navigate\",\"params\":{\"url\":\"https://example.com\"}}";
    try ws_client.vtable.sendFn(ws_client.ptr, navigate_command);

    while (true) {
        const response = try ws_client.vtable.receiveFn(ws_client.ptr);
        defer allocator.free(response);
        std.debug.print("Navigate Response: {s}\n", .{response});
        if (std.mem.indexOf(u8, response, "\"id\":1") != null) break;
    }

    // 2. รอให้หน้าเว็บโหลดเสร็จ
    std.time.sleep(2 * std.time.ns_per_s);

    // 3. สั่งพิมพ์เป็น PDF
    const print_command = 
        \\{"id":2,"method":"Page.printToPDF","params":{
        \\  "landscape": false,
        \\  "printBackground": true,
        \\  "marginTop": 0,
        \\  "marginBottom": 0,
        \\  "marginLeft": 0,
        \\  "marginRight": 0
        \\}}
    ;
    try ws_client.vtable.sendFn(ws_client.ptr, print_command);

    // 4. รับ PDF data และบันทึกลงไฟล์
    while (true) {
        const response = try ws_client.vtable.receiveFn(ws_client.ptr);
        defer allocator.free(response);
        
        if (std.mem.indexOf(u8, response, "\"id\":2") != null) {
            // หา base64 string
            const data_start = std.mem.indexOf(u8, response, "\"data\":\"") orelse continue;
            const base64_start = data_start + 8;
            const base64_end = response.len - 3;
            const base64_data = response[base64_start..base64_end];

            // สร้าง decoder
            const decoder = base64.standard.Decoder;
            
            // สร้าง buffer สำหรับเก็บ PDF
            const pdf_size = try decoder.calcSizeForSlice(base64_data);
            const pdf_data = try allocator.alloc(u8, pdf_size);
            defer allocator.free(pdf_data);
            
            // decode base64
            try decoder.decode(pdf_data, base64_data);

            // บันทึกไฟล์
            const file = try std.fs.cwd().createFile("output.pdf", .{});
            defer file.close();
            try file.writeAll(pdf_data);
            
            std.debug.print("Saved PDF to output.pdf\n", .{});
            break;
        }
    }
}