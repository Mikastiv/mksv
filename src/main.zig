const std = @import("std");
const mksv = @import("mksv");

const RwLock = mksv.RwLock;

fn testRwLockReader(lock: *RwLock, value: *usize) void {
    const read_count = 10000;

    var i: usize = 0;
    while (i < read_count) : (i += 1) {
        lock.lockShared();
        defer lock.unlockShared();

        if (value.* < 20000) {
            i += 1;
        }
    }
}

fn testRwLockWriter(lock: *RwLock, value: *usize) void {
    const write_count = 10000;

    var i: usize = 0;
    while (i < write_count) : (i += 1) {
        lock.lock();
        defer lock.unlock();

        value.* += 1;
    }
}

pub fn main() !void {
    var lock = RwLock.init();
    var value: usize = 0;

    const num_readers = 6;
    const num_writers = 2;

    var threads: [num_readers + num_writers]std.Thread = undefined;
    for (threads[0..num_readers]) |*t| t.* = try std.Thread.spawn(.{}, testRwLockReader, .{ &lock, &value });
    for (threads[num_readers..]) |*t| t.* = try std.Thread.spawn(.{}, testRwLockWriter, .{ &lock, &value });

    for (threads) |t| t.join();

    std.debug.assert(value == num_writers * 10000);
}
