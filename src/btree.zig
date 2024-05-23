const std = @import("std");

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

        allocator: std.mem.Allocator,
        root: ?*Node = null,
        size: usize = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
            };
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

        fn clear(allocator: std.mem.Allocator, node: *Node) void {
            for (node.children[0..node.children_count]) |ptr| {
                clear(ptr);
            }
            allocator.destroy(node);
        }
    };
}
