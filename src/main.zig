const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn printMask(v: u8) void {
    const m = 0b11;

    const a = v & m;
    const b = v >> 2 & m;
    const c = v >> 4 & m;
    const d = v >> 6 & m;

    std.debug.print("0x{X:2}: {d} {d} {d} {d}\n", .{ v, a, b, c, d });
}

pub fn makeMask(comptime a: u8, comptime b: u8, comptime c: u8, comptime d: u8) u8 {
    return d << 6 | c << 4 | b << 2 | a;
}

pub fn main() !void {
    printMask(0x44);
    printMask(0xEE);
    printMask(0x88);
    printMask(0xDD);

    printMask(makeMask(0, 1, 1, 2));

    const c = math.Mat3{
        .{ 6, 1, 1 },
        .{ 4, -2, 5 },
        .{ 2, 8, 7 },
    };
    std.debug.print("{d}\n", .{math.mat.determinant(c)});

    const n = try std.time.Instant.now();
    var r = std.Random.DefaultPrng.init(n.timestamp);
    const rng = r.random();

    var sum: u64 = 0;
    for (0..100000000) |_| {
        const b = math.Mat3{
            .{ rng.float(f32), rng.float(f32), rng.float(f32) },
            .{ rng.float(f32), rng.float(f32), rng.float(f32) },
            .{ rng.float(f32), rng.float(f32), rng.float(f32) },
        };
        const s = try std.time.Instant.now();
        const det = math.mat.determinant(b);
        std.mem.doNotOptimizeAway(det);
        const end = try std.time.Instant.now();

        sum += end.timestamp - s.timestamp;
    }

    std.debug.print("{d}\n", .{sum});
}
