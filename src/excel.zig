// src/excel.zig
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Compressor = std.compress.flate.compressor;

pub const ExcelWriter = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    test_mode: bool,

    pub fn init(allocator: Allocator, test_mode: bool) !ExcelWriter {
        return ExcelWriter{
            .allocator = allocator,
            .buffer = ArrayList(u8).init(allocator),
            .test_mode = test_mode,
        };
    }

    pub fn deinit(self: *ExcelWriter) void {
        self.buffer.deinit();
    }

    fn createWorksheet(self: *ExcelWriter) !void {
        if (self.test_mode) return;

        try self.buffer.appendSlice(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            \\  <sheetData>
        );
    }

    fn createSharedStrings(self: *ExcelWriter) !void {
        if (self.test_mode) return;

        try self.buffer.appendSlice(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        );
    }

    pub fn writeTableData(self: *ExcelWriter, html: []const u8) !void {
        if (self.test_mode) {
            try self.buffer.appendSlice(html);
            return;
        }

        try self.createWorksheet();
        try self.createSharedStrings();
        try self.buffer.appendSlice(html);
        try self.buffer.appendSlice(
            \\  </sheetData>
            \\</worksheet>
        );
    }

    pub fn finish(self: *ExcelWriter) ![]u8 {
        if (self.test_mode) {
            return try self.buffer.toOwnedSlice();
        }

        try self.buffer.appendSlice(
            \\</sst>
        );
        return try self.buffer.toOwnedSlice();
    }
};

const HtmlTableParser = struct {
    allocator: Allocator,
    html: []const u8,
    pos: usize,
    in_row: bool,
    in_cell: bool,

    pub fn init(allocator: Allocator, html: []const u8) !HtmlTableParser {
        return HtmlTableParser{
            .allocator = allocator,
            .html = html,
            .pos = 0,
            .in_row = false,
            .in_cell = false,
        };
    }

    pub fn deinit(self: *HtmlTableParser) void {
        self.* = undefined;
    }

    pub fn nextRow(self: *HtmlTableParser) !?ArrayList([]const u8) {
        var row = ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (row.items) |item| {
                self.allocator.free(item);
            }
            row.deinit();
        }

        while (self.pos < self.html.len) {
            if (try self.findTag("<tr>")) {
                self.in_row = true;
                while (try self.findTag("<td>") or try self.findTag("<th>")) {
                    self.in_cell = true;
                    if (try self.readCellContent()) |content| {
                        try row.append(content);
                    }
                    self.in_cell = false;
                }
                self.in_row = false;
                if (row.items.len > 0) {
                    return row;
                }
            }
        }
        return null;
    }

    fn findTag(self: *HtmlTableParser, tag: []const u8) !bool {
        while (self.pos < self.html.len) {
            if (std.mem.indexOf(u8, self.html[self.pos..], tag)) |index| {
                self.pos += index + tag.len;
                return true;
            }
            self.pos += 1;
        }
        return false;
    }

    fn readCellContent(self: *HtmlTableParser) !?[]const u8 {
        const start = self.pos;
        while (self.pos < self.html.len) {
            if (std.mem.indexOf(u8, self.html[self.pos..], "</td>")) |index| {
                const content = std.mem.trim(u8, self.html[start .. self.pos + index], " \n\r\t");
                self.pos += index + "</td>".len;
                return try self.allocator.dupe(u8, content);
            }
            if (std.mem.indexOf(u8, self.html[self.pos..], "</th>")) |index| {
                const content = std.mem.trim(u8, self.html[start .. self.pos + index], " \n\r\t");
                self.pos += index + "</th>".len;
                return try self.allocator.dupe(u8, content);
            }
            self.pos += 1;
        }
        return null;
    }
};
