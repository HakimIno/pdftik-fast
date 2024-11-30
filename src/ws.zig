// ws.zig
const std = @import("std");
const net = std.net;
const base64 = std.base64;
const crypto = std.crypto;
const Sha1 = crypto.hash.Sha1;
const Allocator = std.mem.Allocator;

// ย้าย BUFFER_SIZE มาไว้ข้างนอกและทำให้เป็น public
pub const BUFFER_SIZE = 65536; // 64KB buffer
pub const TIMEOUT_NS = 30 * std.time.ns_per_s; // 30 seconds timeout

pub const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
};

pub fn parseUrl(allocator: Allocator, url: []const u8) !ParsedUrl {
    if (!std.mem.startsWith(u8, url, "ws://")) {
        return error.InvalidUrl;
    }

    var rest = url[5..];
    const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
    const host_port = rest[0..path_start];
    const path = if (path_start < rest.len)
        rest[path_start..]
    else
        "/";

    const port_sep = std.mem.indexOf(u8, host_port, ":");
    const host = if (port_sep) |sep|
        try allocator.dupe(u8, host_port[0..sep])
    else
        try allocator.dupe(u8, host_port);

    const port = if (port_sep) |sep|
        try std.fmt.parseInt(u16, host_port[sep + 1 ..], 10)
    else
        80;

    return ParsedUrl{
        .host = host,
        .port = port,
        .path = try allocator.dupe(u8, path),
    };
}

pub const WebSocket = struct {
    pub const Error = error{
        ConnectionFailed,
        HandshakeFailed,
        SendFailed,
        ReceiveFailed,
        InvalidResponse,
        InvalidUrl,
        TimeoutError,
    };

    pub const VTable = struct {
        sendFn: *const fn (ctx: *anyopaque, data: []const u8) Error!void,
        receiveFn: *const fn (ctx: *anyopaque) Error![]const u8,
        deinitFn: *const fn (ctx: *anyopaque) void,
    };

    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    url: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
    connected: bool,
    buffer: []u8,
    vtable: *const VTable,
    ptr: *anyopaque,
    is_mock: bool = false,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) !WebSocket {
        _ = allocator;
        _ = url;
        // สำหรับการใช้งานจริง - ยังไม่ implement
        return error.ConnectionFailed;
    }

    pub fn send(self: *WebSocket, data: []const u8) Error!void {
        return self.vtable.sendFn(self.ptr, data);
    }

    pub fn receive(self: *WebSocket) Error![]const u8 {
        return self.vtable.receiveFn(self.ptr);
    }

    pub fn deinit(self: *WebSocket) void {
        if (!self.is_mock) {
            self.stream.close();
        }
        self.vtable.deinitFn(self.ptr);
    }
};
