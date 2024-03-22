const std = @import("std");
const mksv = @import("mksv");

fn testReentrantIncrement(lock: *mksv.ReentrantLock, value: *usize) void {
    for (0..10000) |_| {
        lock.acquire();
        defer lock.release();

        lock.acquire();
        defer lock.release();
        lock.acquire();
        defer lock.release();
        value.* += 1;
    }
}

pub fn main() !void {
    var lock = mksv.ReentrantLock.init();
    var value: usize = 0;

    const t1 = try std.Thread.spawn(.{}, testReentrantIncrement, .{ &lock, &value });
    const t2 = try std.Thread.spawn(.{}, testReentrantIncrement, .{ &lock, &value });
    t1.join();
    t2.join();

    std.debug.print("{d}", .{value});
}
