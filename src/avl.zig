const std = @import("std");

const assert = std.debug.assert;
const testing = std.testing;

pub fn TreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        left: ?*Self = null,
        right: ?*Self = null,
        height: isize = 0,
        value: T,

        fn min(ptr: *Self) ?*Self {
            var node = ptr;
            while (node.left) |n| {
                node = n;
            }
            return node;
        }

        fn max(ptr: *Self) ?*Self {
            var node = ptr;
            while (node.right) |n| {
                node = n;
            }
            return node;
        }
    };
}

pub fn Tree(comptime T: type, comptime compareFn: fn (*const T, *const T) std.math.Order) type {
    return struct {
        pub const Node = TreeNode(T);

        const Self = @This();

        root: ?*Node = null,
        size: usize = 0,

        pub fn find(self: *Self, key: *const T) ?*Node {
            var ptr = self.root;
            while (ptr) |node| {
                const order = compareFn(key, &node.value);
                switch (order) {
                    .lt => ptr = node.left,
                    .gt => ptr = node.right,
                    .eq => return ptr,
                }
            }
            return null;
        }

        pub fn insert(self: *Self, node: *Node) ?*Node {
            var node_preventing: ?*Node = null;
            self.root = insertRecursive(self.root, node, &node_preventing);
            return node_preventing;
        }

        fn insertRecursive(root: ?*Node, node: *Node, node_preventing: *?*Node) ?*Node {
            if (root == null) {
                return node;
            } else switch (compareFn(&node.value, &root.?.value)) {
                .lt => root.?.left = insertRecursive(root.?.left, node, node_preventing),
                .gt => root.?.right = insertRecursive(root.?.right, node, node_preventing),
                .eq => {
                    node_preventing.* = root;
                    return root;
                },
            }

            if (node_preventing.* != null) return root;

            const r = root.?;
            r.height = 1 + @max(height(r.left), height(r.right));

            const bf = height(r.left) - height(r.right);

            if (bf > 1 and compareFn(&node.value, &r.left.?.value) == .lt) {
                return rotateRight(r);
            }
            if (bf < -1 and compareFn(&node.value, &r.right.?.value) == .gt) {
                return rotateLeft(r);
            }
            if (bf > 1 and compareFn(&node.value, &r.left.?.value) == .gt) {
                r.left = rotateLeft(r.left.?);
                return rotateRight(r);
            }
            if (bf < -1 and compareFn(&node.value, &r.right.?.value) == .gt) {
                r.right = rotateRight(r.right.?);
                return rotateLeft(r);
            }

            return r;
        }

        fn rotateLeft(node: *Node) *Node {
            assert(node.right != null);

            const child = node.right.?;
            const y = child.left;

            child.left = node;
            node.right = y;

            node.height = 1 + height(node);
            child.height = 1 + height(child);

            return child;
        }

        fn rotateRight(node: *Node) *Node {
            assert(node.left != null);

            const child = node.left.?;
            const y = child.right;

            child.right = node;
            node.left = y;

            node.height = 1 + height(node);
            child.height = 1 + height(child);

            return child;
        }

        fn height(node: ?*Node) isize {
            return if (node) |n| n.height else 0;
        }

        pub fn debugPrint(self: *const Self) !void {
            var str = std.ArrayList(u8).init(std.heap.page_allocator);
            defer str.deinit();

            const writer = str.writer();

            if (self.root) |r| {
                try writer.print("{d:<3}({d})", .{ r.value, r.height });

                try traverseNodes(writer, r.right, "", "\\--", r.left != null);
                try traverseNodes(writer, r.left, "", "---", false);

                _ = try writer.write("\n");
            }

            std.debug.print("{s}\n", .{str.items});
        }

        fn traverseNodes(
            writer: std.ArrayList(u8).Writer,
            node: ?*Node,
            padding: []const u8,
            pointer: []const u8,
            has_left_sibling: bool,
        ) !void {
            const max_line_len = 1024;
            if (node) |n| {
                try writer.print("\n{s}{s}", .{ padding, pointer });
                try writer.print("{d:<3}({d})", .{ n.value, n.height });

                var buffer = try std.BoundedArray(u8, max_line_len).init(0);
                const w = buffer.writer();
                _ = try w.write(padding);
                _ = try w.write(if (has_left_sibling) "|  " else "   ");

                try traverseNodes(writer, n.right, buffer.constSlice(), "\\--", n.left != null);
                try traverseNodes(writer, n.left, buffer.constSlice(), "---", false);
            }
        }
    };
}

fn compare(a: *const i32, b: *const i32) std.math.Order {
    return std.math.order(a.*, b.*);
}

test "insert" {
    const node_count = 100000;
    const T = Tree(i32, compare);
    var tree = T{};

    var rng = std.Random.DefaultPrng.init(0);
    const rand = rng.random();

    for (0..node_count) |_| {
        var node = try testing.allocator.create(T.Node);
        node.value = rand.int(i32);
        const res = tree.insert(node);
        if (res != null) {
            testing.allocator.destroy(node);
        }
    }
}
