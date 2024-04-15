const std = @import("std");
const tty = std.io.tty;

const assert = std.debug.assert;
const testing = std.testing;

const Color = enum(u1) { red, black };

pub fn TreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        comptime {
            assert(@alignOf(*Self) > 1);
            assert(@typeInfo(Color).Enum.tag_type == u1);
            assert(@intFromEnum(Color.black) == 1);
        }

        const parent_mask: usize = std.math.maxInt(usize) - 1;

        left: ?*Self = null,
        right: ?*Self = null,
        parent_and_color: usize = 0,
        value: T,

        fn parent(self: *const Self) ?*Self {
            const ptr = self.parent_and_color & parent_mask;
            return if (ptr == 0) null else @ptrFromInt(ptr);
        }

        fn setParent(self: *Self, ptr: ?*Self) void {
            self.parent_and_color = @intFromPtr(ptr) | (self.parent_and_color & ~parent_mask);
        }

        fn color(self: *const Self) Color {
            return @enumFromInt(self.parent_and_color & ~parent_mask);
        }

        fn setColor(self: *Self, c: Color) void {
            self.parent_and_color = (self.parent_and_color & parent_mask) | @intFromEnum(c);
        }

        fn isLeftChild(self: *const Self) bool {
            if (self.parent()) |ptr| {
                return ptr.left == self;
            }
            return false;
        }

        fn isRoot(self: *const Self) bool {
            return self.parent() == null;
        }

        fn min(ptr: ?*Self) ?*Self {
            var node = ptr;
            while (node) |n| {
                node = n.left;
            }
            return node;
        }

        fn max(ptr: ?*Self) ?*Self {
            var node = ptr;
            while (node) |n| {
                node = n.right;
            }
            return node;
        }
    };
}

test "node" {
    var n = TreeNode(u8){ .value = 64 };

    const address = ~@as(usize, @alignOf(@TypeOf(n)) - 1);

    n.setColor(.black);
    n.setParent(@ptrFromInt(address));

    try testing.expectEqual(n.color(), Color.black);
    try testing.expectEqual(n.parent(), @as(?*TreeNode(u8), @ptrFromInt(address)));

    n.setColor(.red);
    n.setParent(null);
    try testing.expectEqual(n.color(), Color.red);
    try testing.expectEqual(n.parent(), null);
}

pub fn Tree(comptime T: type, comptime compareFn: fn (*const T, *const T) std.math.Order) type {
    return struct {
        pub const Node = TreeNode(T);

        const Self = @This();

        root: ?*Node = null,
        size: usize = 0,

        pub fn insert(self: *Self, node: *Node) ?*Node {
            var parent: ?*Node = undefined;
            const child = self.findPos(node, &parent);

            if (child.*) |c| {
                return c;
            }

            node.setParent(parent);
            node.left = null;
            node.right = null;
            child.* = node;
            self.size += 1;

            self.insertFix(node);

            return null;
        }

        pub fn remove(self: *Self, node: *Node) void {
            _ = self; // autofix
            _ = node; // autofix
        }

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

        // Case 0: Z == root
        // Case 1: Z->uncle == RED
        //
        // - Color Z's uncle and parent black
        // - Color Z's grandparent red (black if root)
        //
        // Case 2: Z->uncle == BLACK (triangle)
        // Triangle: Right->Left || Left->Right relation
        //
        // - Right rotation on Z's parent
        //
        //                  B   \                     B
        //                 / \   \                   / \
        //       Uncle->  B   R   \    =>   Uncle-> B   R <-Z
        //                   /    /                      \
        //              Z-> R    /                        R
        //
        // Case 3: Z->uncle == BLACK (line)
        // Line: Left->Left || Right->Right relation
        //
        // - Color Z's parent black
        // - Color Z's grandparent red
        // - Left rotation on Z's grandparent
        //
        //
        //                  B   \                     B
        //                 / \   \                   / \
        //       Uncle->  B   R   \    =>           R   R <-Z
        //                     \   \               /
        //                  Z-> R   \     Uncle-> B
        //
        // All cases apply to the mirrored cases
        fn insertFix(self: *Self, node: *Node) void {
            var z = node;
            z.setColor(if (z == self.root) .black else .red); // case 0
            while (z != self.root and z.parent().?.color() == .red) {
                if (z.parent().?.isLeftChild()) {
                    const uncle = z.parent().?.parent().?.right;

                    if (nodeColor(uncle) == .red) { // case 1
                        uncle.?.setColor(.black);
                        z = z.parent().?;
                        z.setColor(.black);
                        z = z.parent().?;
                        z.setColor(if (z == self.root) .black else .red);
                    } else {
                        if (!z.isLeftChild()) { // case 2
                            z = z.parent().?;
                            self.rotateLeft(z);
                        }

                        // case 3
                        z = z.parent().?;
                        z.setColor(.black);
                        z = z.parent().?;
                        z.setColor(.red);
                        self.rotateRight(z);
                        return;
                    }
                } else {
                    const uncle = z.parent().?.parent().?.left;

                    if (nodeColor(uncle) == .red) { // case 1
                        uncle.?.setColor(.black);
                        z = z.parent().?;
                        z.setColor(.black);
                        z = z.parent().?;
                        z.setColor(if (z == self.root) .black else .red);
                    } else {
                        if (z.isLeftChild()) { // case 2
                            z = z.parent().?;
                            self.rotateRight(z);
                        }

                        // case 3
                        z = z.parent().?;
                        z.setColor(.black);
                        z = z.parent().?;
                        z.setColor(.red);
                        self.rotateLeft(z);
                        return;
                    }
                }
            }
        }

        fn findPos(self: *Self, key: *const Node, parent: *?*Node) *?*Node {
            var node = self.root;
            var ptr = &self.root;

            while (node) |n| {
                const order = compareFn(&key.value, &n.value);
                switch (order) {
                    .lt => {
                        if (n.left) |left| {
                            ptr = &n.left;
                            node = left;
                        } else {
                            parent.* = n;
                            return &n.left;
                        }
                    },
                    .gt => {
                        if (n.right) |right| {
                            ptr = &n.right;
                            node = right;
                        } else {
                            parent.* = node;
                            return &n.right;
                        }
                    },
                    .eq => {
                        parent.* = node;
                        return ptr;
                    },
                }
            }

            parent.* = null;
            return ptr;
        }

        fn rotateLeft(self: *Self, node: *Node) void {
            const ptr = node.right.?;

            node.right = ptr.left;
            if (ptr.left) |p| {
                p.setParent(node);
            }
            ptr.left = node;
            ptr.setParent(node.parent());
            if (node.isRoot()) {
                self.root = ptr;
                self.root.?.setParent(null);
            } else {
                if (node.isLeftChild()) {
                    node.parent().?.left = ptr;
                } else {
                    node.parent().?.right = ptr;
                }
            }
            node.setParent(ptr);
        }

        fn rotateLeftWithRoot(self: *Self, node: *Node) void {
            if (self.root == node) {
                self.root = node.right;
            }

            self.rotateLeft(node);
        }

        fn rotateRight(self: *Self, node: *Node) void {
            const ptr = node.left.?;

            node.left = ptr.right;
            if (ptr.right) |p| {
                p.setParent(node);
            }
            ptr.right = node;
            ptr.setParent(node.parent());
            if (node.isRoot()) {
                self.root = ptr;
                self.root.?.setParent(null);
            } else {
                if (node.isLeftChild()) {
                    node.parent().?.left = ptr;
                } else {
                    node.parent().?.right = ptr;
                }
            }
            node.setParent(ptr);
        }

        fn rotateRightWithRoot(self: *Self, node: *Node) void {
            if (self.root == node) {
                self.root = node.left;
            }

            self.rotateRight(node);
        }

        fn nodeColor(ptr: ?*Node) Color {
            if (ptr) |node| {
                return node.color();
            }
            return .black;
        }

        fn blackHeight(ptr: ?*Node) ?u64 {
            if (ptr == null) return 1;

            const node = ptr.?;

            if (node.left != null and node.left.?.parent() != node)
                return null;
            if (node.right != null and node.right.?.parent() != node)
                return null;
            if (node.left == node.right and node.left != null)
                return null;

            const height = blackHeight(node.left);
            if (height == null)
                return null;
            if (height != blackHeight(node.right))
                return null;

            return height.? + @intFromEnum(node.color());
        }

        fn isRedBlackTree(self: *const Self) bool {
            if (self.root == null) return true;

            const r = self.root.?;

            if (r.parent() != null) return false;
            if (r.color() != .black) return false;

            return blackHeight(self.root) != null;
        }

        pub fn debugPrint(self: *const Self) !void {
            var str = std.ArrayList(u8).init(std.heap.page_allocator);
            defer str.deinit();

            const writer = str.writer();

            if (self.root) |r| {
                const config = tty.detectConfig(std.io.getStdOut());
                try tty.Config.setColor(config, writer, if (r.color() == .black) .black else .red);
                try writer.print("{d:<3}", .{r.value});
                try tty.Config.setColor(config, writer, .reset);

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
            const max_line_len = 128;
            if (node) |n| {
                try writer.print("\n{s}{s}", .{ padding, pointer });

                const config = tty.detectConfig(std.io.getStdOut());
                try tty.Config.setColor(config, writer, if (n.color() == .black) .black else .red);
                try writer.print("{d:<3}", .{n.value});
                try tty.Config.setColor(config, writer, .reset);

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
    const T = Tree(i32, compare);
    var tree = T{};

    var nodes: [10]T.Node = .{
        .{ .value = 32 },
        .{ .value = 64 },
        .{ .value = 0 },
        .{ .value = 1 },
        .{ .value = 8 },
        .{ .value = 26 },
        .{ .value = 42 },
        .{ .value = 2 },
        .{ .value = 3 },
        .{ .value = 4 },
    };

    _ = tree.insert(&nodes[0]);
    _ = tree.insert(&nodes[1]);
    _ = tree.insert(&nodes[2]);
    _ = tree.insert(&nodes[4]);
    _ = tree.insert(&nodes[3]);
    _ = tree.insert(&nodes[5]);
    _ = tree.insert(&nodes[7]);
    _ = tree.insert(&nodes[6]);
    _ = tree.insert(&nodes[8]);
    _ = tree.insert(&nodes[9]);

    try testing.expect(tree.isRedBlackTree());
}
