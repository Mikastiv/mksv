const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

pub fn Tree(
    comptime T: type,
    comptime b: usize,
    comptime compareFn: fn (*const T, *const T) std.math.Order,
) type {
    return struct {
        const Self = @This();

        const node_capacity = b * 2 - 1;
        const node_min = b - 1;
        const children_capacity = b * 2;
        const children_min = b;

        pub const Node = struct {
            items: [node_capacity]T,
            children: [children_capacity]*Node,
            items_count: u32,
            children_count: u32,
        };

        allocator: Allocator,
        root: ?*Node = null,
        size: usize = 0,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
            };
        }

        pub fn insert(self: *Self, key: *const T) Allocator.Error!?*T {
            if (self.root == null) {
                const node = try self.allocator.create(Node);
                node.items[0] = key.*;
                node.items_count = 1;
                node.children_count = 0;
                return null;
            }

            const root = self.root.?;
            if (root.items_count >= node_capacity) {
                // split
            }
        }

        pub fn find(self: *const Self, key: *const T) ?*T {
            if (self.root == null) return null;

            var node = self.root.?;
            while (true) {
                var i: usize = 0;
                while (i < node.items_count) : (i += 1) {
                    switch (compareFn(key, &node.items[i])) {
                        .eq => return &node.items[i],
                        .gt => break,
                        .lt => {},
                    }
                }

                if (i >= node.children_count) break;

                node = node.children[i];
            }

            return null;
        }

        pub fn deinit(self: *Self) void {
            if (self.root) |root| clear(self.allocator, root);
            self.size = 0;
        }

        fn clear(allocator: Allocator, node: *Node) void {
            for (node.children[0..node.children_count]) |ptr| {
                clear(ptr);
            }
            allocator.destroy(node);
        }
    };
}
