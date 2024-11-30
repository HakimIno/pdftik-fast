const std = @import("std");
const ChildProcess = std.process.Child;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // สร้าง HTML content
    var html = std.ArrayList(u8).init(allocator);
    defer html.deinit();

    // เพิ่ม HTML header
    try html.appendSlice(
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<meta charset="UTF-8" />
        \\<style>
        \\  table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        \\  th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        \\  th { background-color: #f5f5f5; }
        \\  .product-image { width: 100px; height: auto; }
        \\  .header { text-align: center; margin: 20px 0; }
        \\  @page { size: A4; margin: 20mm; }
        \\  .page-break { page-break-after: always; }
        \\</style>
        \\</head>
        \\<body>
    );

    // สร้าง 500 หน้า
    var page: usize = 0;
    while (page < 500) : (page += 1) {
        // Header สำหรับแต่ละหน้า
        const header = try std.fmt.allocPrint(
            allocator,
            \\<div class="header">
            \\  <h1>รายการสินค้า - หน้า {d}/500</h1>
            \\  <p>วันที่พิมพ์: 15 มิถุนายน 2567</p>
            \\</div>
            \\<table>
            \\  <thead>
            \\    <tr>
            \\      <th>รหัสสินค้า</th>
            \\      <th>ชื่อสินค้า</th>
            \\      <th>ราคา</th>
            \\      <th>จำนวนคงเหลือ</th>
            \\    </tr>
            \\  </thead>
            \\  <tbody>
            ,
            .{page + 1}
        );
        defer allocator.free(header);
        try html.appendSlice(header);

        // สร้างข้อมูลสินค้า 10 รายการต่อหน้า
        var item: usize = 0;
        while (item < 10) : (item += 1) {
            const product_id = page * 10 + item;
            const row = try std.fmt.allocPrint(
                allocator,
                \\    <tr>
                \\      <td>P{d:0>4}</td>
                \\      <td>สินค้า {d}</td>
                \\      <td>฿{d},000</td>
                \\      <td>{d}</td>
                \\    </tr>
                ,
                .{
                    product_id + 1,
                    product_id + 1,
                    (product_id * 2) + 10,
                    (product_id * 3) + 50,
                }
            );
            defer allocator.free(row);
            try html.appendSlice(row);
        }

        // ปิด table
        try html.appendSlice(
            \\  </tbody>
            \\</table>
        );

        // เพิ่ม page break ยกเว้นหน้าสุดท้าย
        if (page < 499) {
            try html.appendSlice("<div class='page-break'></div>");
        }
    }

    // ปิด HTML
    try html.appendSlice("</body></html>");

    // บันทึก HTML และแปลงเป็น PDF
    const html_path = "temp.html";
    const html_file = try std.fs.cwd().createFile(html_path, .{});
    defer {
        html_file.close();
        std.fs.cwd().deleteFile(html_path) catch {};
    }
    try html_file.writeAll(html.items);

    std.debug.print("Converting to PDF (500 pages)...\n", .{});

    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    try args.appendSlice(&[_][]const u8{
        "wkhtmltopdf",
        "--page-size", "A4",
        "--enable-local-file-access",
        "--disable-smart-shrinking",
        "--print-media-type",
        html_path,
        "output.pdf",
    });

    var process = ChildProcess.init(args.items, allocator);
    process.stderr_behavior = .Pipe;
    process.stdout_behavior = .Pipe;

    try process.spawn();
    const result = try process.wait();

    if (result != .Exited or result.Exited != 0) {
        if (process.stderr) |stderr| {
            const err_msg = try stderr.reader().readAllAlloc(allocator, 1024);
            defer allocator.free(err_msg);
            std.debug.print("Error: {s}\n", .{err_msg});
        }
        return error.WkhtmltopdfError;
    }

    const pdf_size = (try std.fs.cwd().statFile("output.pdf")).size;
    std.debug.print("Done! Created PDF: output.pdf ({d} bytes)\n", .{pdf_size});
}