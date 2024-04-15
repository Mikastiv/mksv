const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn less(a: *const u32, b: *const u32) std.math.Order {
    return std.math.order(a.*, b.*);
}

pub fn main() !void {
    const T = mksv.rb.Tree(u32, less);
    const node_count = 100000;

    var tree = T{};

    var rng = std.Random.DefaultPrng.init(0);
    const rand = rng.random();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    for (0..node_count) |_| {
        var node = try allocator.create(T.Node);
        node.value = rand.int(u32);
        _ = tree.insert(node);
    }

    while (tree.size > 0) {
        const target = tree.root.?;
        tree.remove(target);
    }

    if (!tree.isRedBlackTree()) {
        @panic("not red black tree");
    }

    for (0..node_count / 2) |_| {
        var node = try allocator.create(T.Node);
        node.value = rand.int(u32);
        _ = tree.insert(node);
    }

    while (tree.size > node_count / 4) {
        const target = tree.root.?;
        tree.remove(target);
    }

    for (0..node_count / 2) |_| {
        var node = try allocator.create(T.Node);
        node.value = rand.int(u32);
        _ = tree.insert(node);
    }

    if (!tree.isRedBlackTree()) {
        @panic("not red black tree");
    }

    while (tree.size > node_count / 4) {
        const target = tree.root.?;
        tree.remove(target);
    }

    if (!tree.isRedBlackTree()) {
        @panic("not red black tree");
    }

    while (tree.size > 0) {
        const target = tree.root.?;
        tree.remove(target);
    }
}
