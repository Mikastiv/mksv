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
    const allocator = std.heap.page_allocator;

    // const T = mksv.avl.Tree(u32, less);
    // var tree = T{};

    // var rng = std.Random.DefaultPrng.init(0);
    // const rand = rng.random();

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

    const stack_size = std.mem.page_size * 4;

    var data1: FiberData = .{
        .text = "hello",
    };
    var data2: FiberData = .{
        .text = "world",
    };

    main_fiber = try mksv.Fiber.switchThreadToFiber();
    defer main_fiber.deinit();

    read_fiber = try mksv.Fiber.init(allocator, stack_size, read, @ptrCast(&data1));
    defer read_fiber.deinit();

    write_fiber = try mksv.Fiber.init(allocator, stack_size, write, @ptrCast(&data2));
    defer write_fiber.deinit();

    main_fiber.switchTo(&read_fiber);
}

var main_fiber: mksv.Fiber = undefined;
var read_fiber: mksv.Fiber = undefined;
var write_fiber: mksv.Fiber = undefined;

var count: usize = 0;
var done: bool = false;

fn read(ptr: ?*anyopaque) callconv(.C) noreturn {
    const data: *FiberData = @ptrCast(@alignCast(ptr));
    while (true) {
        if (done) break;
        if (count >= 10) done = true;

        std.debug.print("{s} {d}\n", .{ data.text, count });

        read_fiber.switchTo(&write_fiber);

        std.time.sleep(std.time.ns_per_s);
    }

    read_fiber.switchTo(&main_fiber);

    unreachable;
}

fn write(ptr: ?*anyopaque) callconv(.C) noreturn {
    const data: *FiberData = @ptrCast(@alignCast(ptr));
    while (true) {
        std.debug.print("{s} {d}\n", .{ data.text, count });
        count += 1;
        write_fiber.switchTo(&read_fiber);
        std.time.sleep(std.time.ns_per_s);
    }

    unreachable;
}
