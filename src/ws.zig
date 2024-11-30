const std = @import("std");
const net = std.net;
const Uri = std.Uri;
const os = std.os;
const windows = os.windows;
const builtin = @import("builtin");
const atomic = std.atomic;

pub const WebSocket = struct {
    allocator: std.mem.Allocator,
    stream: *net.Stream,
    url: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
    connected: bool,
    buffer: []u8,
    vtable: *const VTable,
    ptr: *anyopaque,
    is_mock: bool,
    handle_closed: bool = false,
    handle_state: atomic.Value(i32),

    pub const VTable = struct {
        sendFn: *const fn (ctx: *anyopaque, data: []const u8) Error!void,
        receiveFn: *const fn (ctx: *anyopaque) Error![]const u8,
        deinitFn: *const fn (ctx: *anyopaque) void,
    };

    pub const Error = error{
        ConnectionFailed,
        HandshakeFailed,
        InvalidResponse,
        TimeoutError,
        InvalidUrl,
        AccessDenied,
        Unexpected,
        SystemResources,
        WouldBlock,
        InputOutput,
        OperationAborted,
        BrokenPipe,
        ConnectionResetByPeer,
        ConnectionTimedOut,
        NotOpenForReading,
        NotOpenForWriting,
        SocketNotConnected,
        IsDir,
        FileTooBig,
        NoSpaceLeft,
        DeviceBusy,
        DiskQuota,
        InvalidArgument,
        LockViolation,
        ConnectionClosed,
        OutOfMemory,
    };

    pub fn init(allocator: std.mem.Allocator, url: []const u8) !*WebSocket {
        const ws = try allocator.create(WebSocket);
        errdefer allocator.destroy(ws);

        // Parse URL
        const parsed_url = try std.Uri.parse(url);
        
        // Get host
        const host = switch (parsed_url.host.?) {
            .raw => |h| try allocator.dupe(u8, h),
            .percent_encoded => |h| try allocator.dupe(u8, h),
        };
        errdefer allocator.free(host);
        
        // Get path
        const path = switch (parsed_url.path) {
            .raw => |p| try allocator.dupe(u8, p),
            .percent_encoded => |p| try allocator.dupe(u8, p),
        };
        errdefer allocator.free(path);
        
        // Duplicate URL
        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        // Create stream
        var stream = try allocator.create(net.Stream);
        errdefer allocator.destroy(stream);

        stream.* = try net.tcpConnectToHost(
            allocator,
            host,
            parsed_url.port orelse 9222,
        );

        // Perform handshake
        const handshake = try std.fmt.allocPrint(allocator,
            "GET {s} HTTP/1.1\r\n" ++
            "Host: {s}:{d}\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ++
            "Sec-WebSocket-Version: 13\r\n\r\n",
            .{ 
                path, 
                host, 
                parsed_url.port orelse 9222,
            }
        );
        defer allocator.free(handshake);

        // Add debug logs for handshake
        std.debug.print("Sending handshake:\n{s}\n", .{handshake});
        try stream.writeAll(handshake);

        var response_buffer: [1024]u8 = undefined;
        const bytes_read = try stream.read(&response_buffer);
        
        std.debug.print("Received handshake response:\n{s}\n", .{response_buffer[0..bytes_read]});
        
        if (!std.mem.startsWith(u8, response_buffer[0..bytes_read], "HTTP/1.1 101")) {
            stream.close();
            return error.HandshakeFailed;
        }

        // เพิ่มการรอหลังจาก handshake
        std.time.sleep(1 * std.time.ns_per_s); // รอ 1 วินาที

        ws.* = .{
            .allocator = allocator,
            .stream = stream,
            .url = url_copy,
            .host = host,
            .port = parsed_url.port orelse 9222,
            .path = path,
            .connected = true,
            .buffer = &[_]u8{},
            .vtable = &WebSocket.VTable{
                .sendFn = realSendFn,
                .receiveFn = realReceiveFn,
                .deinitFn = realDeinitFn,
            },
            .ptr = @ptrCast(@alignCast(ws)),
            .is_mock = false,
            .handle_state = atomic.Value(i32).init(0),
        };

        // ส่งคำสั่งเริ่มต้นเพื่อเตรียม Chrome
        try ws.sendCommand("Target.createTarget", .{
            .url = "about:blank"
        });

        // รอให้ Chrome ตอบกลับ
        std.time.sleep(500 * std.time.ns_per_ms);

        return ws;
    }

    fn realSendFn(ctx: *anyopaque, data: []const u8) Error!void {
        const ws = @as(*WebSocket, @ptrCast(@alignCast(ctx)));
        if (!ws.connected) return error.ConnectionClosed;

        std.debug.print("Sending data: {s}\n", .{data});

        // สร้าง WebSocket frame
        var frame: [14]u8 = undefined;
        frame[0] = 0x81; // FIN + text frame
        frame[1] = 0x80; // Set mask bit
        
        var payload_offset: usize = 2;
        if (data.len < 126) {
            frame[1] |= @as(u8, @intCast(data.len));
        } else if (data.len < 65536) {
            frame[1] |= 126;
            frame[2] = @as(u8, @intCast((data.len >> 8) & 0xFF));
            frame[3] = @as(u8, @intCast(data.len & 0xFF));
            payload_offset = 4;
        } else {
            frame[1] |= 127;
            const len = @as(u64, data.len);
            frame[2] = @as(u8, @intCast((len >> 56) & 0xFF));
            frame[3] = @as(u8, @intCast((len >> 48) & 0xFF));
            frame[4] = @as(u8, @intCast((len >> 40) & 0xFF));
            frame[5] = @as(u8, @intCast((len >> 32) & 0xFF));
            frame[6] = @as(u8, @intCast((len >> 24) & 0xFF));
            frame[7] = @as(u8, @intCast((len >> 16) & 0xFF));
            frame[8] = @as(u8, @intCast((len >> 8) & 0xFF));
            frame[9] = @as(u8, @intCast(len & 0xFF));
            payload_offset = 10;
        }

        // ใส่ masking key
        const mask_key = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
        @memcpy(frame[payload_offset..][0..4], &mask_key);
        payload_offset += 4;

        try ws.stream.writeAll(frame[0..payload_offset]);

        var masked_data = try ws.allocator.alloc(u8, data.len);
        defer ws.allocator.free(masked_data);
        
        for (data, 0..) |byte, i| {
            masked_data[i] = byte ^ mask_key[i % 4];
        }
        try ws.stream.writeAll(masked_data);

        std.debug.print("Frame sent successfully\n", .{});
    }

    fn realReceiveFn(ctx: *anyopaque) Error![]const u8 {
        const ws = @as(*WebSocket, @ptrCast(@alignCast(ctx)));
        if (!ws.connected) return error.ConnectionClosed;

        std.debug.print("Waiting for Chrome response...\n", .{});
        
        var tries: u8 = 0;
        while (tries < 10) : (tries += 1) { // เพิ่มจำนวนครั้งที่ลอง
            var header: [2]u8 = undefined;
            const header_len = ws.stream.read(&header) catch |err| {
                std.debug.print("Read error: {}\n", .{err});
                if (tries == 9) return err; // ถ้าเป็นครั้งสุดท้ายให้ return error
                std.time.sleep(500 * std.time.ns_per_ms); // เพิ่มเวลารอเป็น 500ms
                continue;
            };
            
            std.debug.print("Try {d}: Header length: {d}\n", .{tries, header_len});
            if (header_len >= 2) {
                std.debug.print("Header bytes: {any}\n", .{header[0..header_len]});
                
                // อำนวณ payload length
                var payload_len: usize = @as(usize, header[1] & 0x7F);
                if (payload_len == 126) {
                    var len_bytes: [2]u8 = undefined;
                    _ = try ws.stream.read(&len_bytes);
                    payload_len = (@as(usize, len_bytes[0]) << 8) | len_bytes[1];
                } else if (payload_len == 127) {
                    var len_bytes: [8]u8 = undefined;
                    _ = try ws.stream.read(&len_bytes);
                    payload_len = 0;
                    for (len_bytes) |byte| {
                        payload_len = (payload_len << 8) | byte;
                    }
                }
                
                // อ่านและแสดงข้อมูลที่ได้รับ
                var payload = try ws.allocator.alloc(u8, payload_len);
                errdefer ws.allocator.free(payload);
                
                var total_read: usize = 0;
                while (total_read < payload_len) {
                    const read_len = try ws.stream.read(payload[total_read..]);
                    if (read_len == 0) break;
                    total_read += read_len;
                }

                std.debug.print("Received data: {s}\n", .{payload[0..total_read]});
                return payload;
            }
            
            std.time.sleep(500 * std.time.ns_per_ms);
        }
        
        return error.InvalidResponse;
    }

    fn realDeinitFn(ctx: *anyopaque) void {
        const ws = @as(*WebSocket, @ptrCast(@alignCast(ctx)));
        if (ws.stream.handle != -1) {
            ws.stream.close();
        }
    }

    pub fn deinit(self: *WebSocket) void {
        if (!self.is_mock) {
            self.vtable.deinitFn(self.ptr);
        }
        
        self.allocator.free(self.host);
        self.allocator.free(self.path);
        self.allocator.free(self.url);
        if (self.buffer.len > 0) {
            self.allocator.free(self.buffer);
        }
        if (!self.is_mock) {
            self.allocator.destroy(self.stream);
        }
        self.allocator.destroy(self);
    }

    pub fn sendCommand(self: *WebSocket, command: []const u8, params: anytype) !void {
        const json = try std.json.stringifyAlloc(self.allocator, .{
            .method = command,
            .params = params,
        }, .{});
        defer self.allocator.free(json);
        
        try self.vtable.sendFn(self.ptr, json);
    }
};