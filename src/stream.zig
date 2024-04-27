const std = @import("std");

const assert = std.debug.assert;

pub fn BitStream(comptime Reader: type, comptime endian: std.builtin.Endian) type {
    return struct {
        const Self = @This();

        reader: Reader,
        byte: ?u8 = null,
        bit_index: u8 = if (endian == .big) 7 else 0,

        pub fn init(reader: Reader) Self {
            return .{
                .reader = reader,
            };
        }

        pub fn readBits(self: *Self, count: u4) !u8 {
            assert(count > 0 and count <= 8);

            if (self.byte == null) {
                self.byte = try self.reader.readByte();
            }

            const bits_remaining = self.bitsRemaining();
            assert(count <= bits_remaining);

            const byte = self.byte.?;

            if (count == 8) return byte;

            const shift: u3 = @intCast(if (endian == .big) self.bit_index - (count - 1) else self.bit_index);
            const mask: u8 = @intCast(((@as(u16, 1) << count) - 1) << shift);
            const value = (byte & mask) >> shift;

            if (endian == .big) {
                if (bits_remaining - count == 0) {
                    self.byte = null;
                    self.bit_index = 7;
                } else {
                    self.bit_index -= count;
                }
            } else {
                if (bits_remaining - count == 0) {
                    self.byte = null;
                    self.bit_index = 0;
                } else {
                    self.bit_index += count;
                }
            }

            return if (endian == .big)
                value
            else
                @bitReverse(value) >> @intCast(8 - count);
        }

        fn bitsRemaining(self: *const Self) u8 {
            if (self.byte == null) return 0;

            return if (endian == .big)
                self.bit_index + 1
            else
                8 - self.bit_index;
        }
    };
}

const testing = std.testing;

test "bit stream" {
    const bytes: [4]u8 = .{ 0b01001101, 0b11011000, 0b11110000, 0b10101010 };
    var buf_stream = std.io.fixedBufferStream(&bytes);

    var bit_stream_big = BitStream(@TypeOf(buf_stream).Reader, .big).init(buf_stream.reader());

    try testing.expectEqual(0b010, try bit_stream_big.readBits(3));
    try testing.expectEqual(0b01101, try bit_stream_big.readBits(5));
    try testing.expectEqual(0b1, try bit_stream_big.readBits(1));
    try testing.expectEqual(0b10, try bit_stream_big.readBits(2));
    try testing.expectEqual(0b1, try bit_stream_big.readBits(1));
    try testing.expectEqual(0b1000, try bit_stream_big.readBits(4));
    try testing.expectEqual(0b11110000, try bit_stream_big.readBits(8));
    try testing.expectEqual(0b10, try bit_stream_big.readBits(2));
    try testing.expectEqual(0b10, try bit_stream_big.readBits(2));
    try testing.expectEqual(0b10, try bit_stream_big.readBits(2));
    try testing.expectEqual(0b10, try bit_stream_big.readBits(2));

    buf_stream.reset();
    var bit_stream_little = BitStream(@TypeOf(buf_stream).Reader, .little).init(buf_stream.reader());

    try testing.expectEqual(0b101, try bit_stream_little.readBits(3));
    try testing.expectEqual(0b10010, try bit_stream_little.readBits(5));
    try testing.expectEqual(0b0, try bit_stream_little.readBits(1));
    try testing.expectEqual(0b00, try bit_stream_little.readBits(2));
    try testing.expectEqual(0b1, try bit_stream_little.readBits(1));
    try testing.expectEqual(0b1011, try bit_stream_little.readBits(4));
    try testing.expectEqual(0b00001111, try bit_stream_little.readBits(8));
    try testing.expectEqual(0b01, try bit_stream_little.readBits(2));
    try testing.expectEqual(0b01, try bit_stream_little.readBits(2));
    try testing.expectEqual(0b01, try bit_stream_little.readBits(2));
    try testing.expectEqual(0b01, try bit_stream_little.readBits(2));
}
