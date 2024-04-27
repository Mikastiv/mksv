const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn less(a: *const u32, b: *const u32) std.math.Order {
    return std.math.order(a.*, b.*);
}

const FiberData = struct {
    text: [*:0]const u8,
};

pub fn main() !void {
    // const allocator = std.heap.page_allocator;
    // _ = allocator; // autofix

    // const T = mksv.avl.Tree(u32, less);
    // var tree = T{};

    var rng = std.Random.DefaultPrng.init(0);
    const rand = rng.random();

    // var nodes = [10]T.Node{
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    //     .{ .value = rand.int(u32) % 64 },
    // };

    // _ = tree.insert(&nodes[0]);
    // _ = tree.insert(&nodes[1]);
    // _ = tree.insert(&nodes[2]);
    // _ = tree.insert(&nodes[3]);
    // _ = tree.insert(&nodes[4]);
    // _ = tree.insert(&nodes[5]);
    // _ = tree.insert(&nodes[6]);
    // _ = tree.insert(&nodes[7]);
    // _ = tree.insert(&nodes[8]);

    // try tree.debugPrint();

    var bytes: [3]u8 = undefined;
    rand.bytes(&bytes);

    for (bytes) |b| {
        std.debug.print("{b:0>8} ", .{b});
    }
    std.debug.print("\n", .{});

    var buf_stream = std.io.fixedBufferStream(&bytes);

    var stream = mksv.bit_stream.BitStream(@TypeOf(buf_stream).Reader, .big).init(buf_stream.reader());

    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b:0>5}", .{try stream.readBits(5)});
    std.debug.print("{b}\n", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b}\n", .{try stream.readBits(1)});
    std.debug.print("{b}", .{try stream.readBits(1)});
    std.debug.print("{b:0>7}\n", .{try stream.readBits(7)});

    buf_stream.reset();
    var stream_little = mksv.bit_stream.StaticStream(@TypeOf(buf_stream).Reader, .little).init(buf_stream.reader());

    std.debug.print("{b}", .{try stream_little.readBits(1)});
    std.debug.print("{b}", .{try stream_little.readBits(1)});
    std.debug.print("{b:0>5}", .{try stream_little.readBits(5)});
    std.debug.print("{b}\n", .{try stream_little.readBits(1)});
}
