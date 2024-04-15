const std = @import("std");
const tty = std.io.tty;

const assert = std.debug.assert;
const testing = std.testing;

const Color = enum(u1) { red, black };

pub fn TreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const NodeType = enum { root, left_child, right_child };

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

        fn nodeType(self: *const Self) NodeType {
            if (self.parent()) |ptr| {
                return if (ptr.left == self)
                    .left_child
                else
                    .right_child;
            }
            return .root;
        }

        fn isRoot(self: *const Self) bool {
            return self.parent() == null;
        }

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

            node.parent_and_color = 0;
            node.setParent(parent);
            node.left = null;
            node.right = null;
            child.* = node;
            self.size += 1;

            self.insertFix(node);

            return null;
        }

        pub fn remove(self: *Self, target: *Node) void {
            assert(self.size > 0);

            var y = target;

            // Find node to replace target if target has 2 child (in order successor).
            if (target.left != null and target.right != null) {
                y = target.right.?.min().?;
            }

            // x is null or y's only child.
            const x = if (y.left != null) y.left else y.right;

            var x_parent = y.parent();

            // Replace y with x.
            if (x) |node| {
                node.setParent(y.parent());
            }

            switch (y.nodeType()) {
                .root => self.root = x,
                .left_child => y.parent().?.left = x,
                .right_child => {
                    // If y is target's right child, update x_parent because target will be replaced by y later.
                    if (target.right == y) {
                        x_parent = y;
                    }
                    y.parent().?.right = x;
                },
            }

            const removed_black = y.color() == .black;

            // If y is target's in order successor, transplant y into target's place.
            if (y != target) {
                y.setColor(target.color());
                y.setParent(target.parent());

                switch (target.nodeType()) {
                    .root => self.root = y,
                    .left_child => y.parent().?.left = y,
                    .right_child => y.parent().?.right = y,
                }

                y.left = target.left;
                if (y.left) |node| {
                    node.setParent(y);
                }

                y.right = target.right;
                if (y.right) |node| {
                    node.setParent(y);
                }
            }

            self.size -= 1;

            // Balance tree only if a black node was removed.
            if (removed_black) {
                // Tree is empty, nothing to do (root double black case).
                if (self.root == null) return;

                // x is red, color it black.
                if (x) |node| {
                    node.setColor(.black);
                    return;
                }

                self.removeFix(x_parent.?);
            }
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
                if (z.parent().?.nodeType() == .left_child) {
                    const uncle = z.parent().?.parent().?.right;

                    if (nodeColor(uncle) == .red) { // case 1
                        uncle.?.setColor(.black);
                        z = z.parent().?;
                        z.setColor(.black);
                        z = z.parent().?;
                        z.setColor(if (z == self.root) .black else .red);
                    } else {
                        if (z.nodeType() == .right_child) { // case 2
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
                        if (z.nodeType() == .left_child) { // case 2
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

        // P: Parent
        // X: Double black node
        // W: X's sibling
        //
        // Case 0: Root is double black node (terminal case)
        //     - Nothing to do
        //
        // Case 1: Black parent (P), red sibling (W) with two black child
        //
        //     - Left rotation on parent
        //     - Recolor parent and W
        //
        //        P-> B                        W-> B
        //           / \                          / \
        //     X->  DB  R <-W     ==>        P-> R   B <-Z
        //             / \                      / \
        //        Y-> B   B <-Z            X-> DB  B <-Y
        //
        // Case 2: Black parent (P), black sibling (W) with two black child
        //
        //     - Recolor W
        //     - Parent becomes X
        //
        //        P-> B                    New X-> B
        //           / \                          / \
        //     X->  DB  B <-W     ==>    Old X-> B   R <-W
        //             / \                          / \
        //        Y-> B   B <-Z               Y->  B   B <-Z
        //
        // Case 3: Red parent (P), black sibling (W) with two black child (terminal case)
        //
        //     - Recolor parent and W
        //
        //        P-> R                        P-> B
        //           / \                          / \
        //     X->  DB  B <-W     ==>        X-> B   R <-W
        //             / \                          / \
        //        Y-> B   B <-Z               Y->  B   B <-Z
        //
        // Case 4: Black parent (P), black sibling (W) with red left child (Y) and black right child (B)
        //
        //     - Right rotation on W
        //     - Recolor Y and W
        //
        //        P-> B                        P-> B
        //           / \                          / \
        //     X->  DB  B <-W     ==>        X-> DB  B <-Y
        //             / \                            \
        //        Y-> R   B <-Z                        R <-W
        //                                              \
        //                                               B <-Z
        //
        // Case 5: Red or black parent (P), black sibling (W) with red or black left child (Y)
        //         and red right child (B) (terminal case)
        //
        //     - Left rotation on parent
        //     - Color W with parent's color
        //     - Color parent and Z black
        //
        //        P-> RB                       W-> RB
        //           / \                          / \
        //     X->  DB  B <-W     ==>        P-> B   B <-Z
        //             / \                      / \
        //        Y-> RB  R <-Z            X-> B  RB <-Y
        //
        // All cases apply to the mirrored cases
        //
        // This function should only be called to fix a double black node case
        fn removeFix(self: *Self, x_parent: *Node) void {
            var x: ?*Node = null; // double black nodes always start as a null pointer
            var parent: ?*Node = x_parent;

            while (self.root != x and nodeColor(x) == .black) {
                const p = parent.?; // always has a parent when not root
                if (x == p.left) {
                    var w = p.right.?;

                    if (w.color() == .red) { // case 1
                        p.setColor(.red);
                        w.setColor(.black);
                        self.rotateLeftWithRoot(p);
                        w = p.right.?;
                    }

                    if (nodeColor(w.left) == .black and nodeColor(w.right) == .black) { // case 2 and case 3
                        w.setColor(.red);
                        x = p;
                        parent = p.parent();
                    } else {
                        if (nodeColor(w.right) == .black) { // case 4
                            w.setColor(.red);
                            self.rotateRightWithRoot(w);
                            w = p.right.?;
                            w.setColor(.black);
                        }

                        // case 5
                        w.setColor(p.color());
                        p.setColor(.black);
                        w.right.?.setColor(.black);
                        self.rotateLeftWithRoot(p);
                        x = self.root;
                        break;
                    }
                } else {
                    var w = p.left.?;

                    if (w.color() == .red) { // case 1
                        p.setColor(.red);
                        w.setColor(.black);
                        self.rotateRightWithRoot(p);
                        w = p.left.?;
                    }

                    if (nodeColor(w.right) == .black and nodeColor(w.left) == .black) { // case 2 and case 3
                        w.setColor(.red);
                        x = p;
                        parent = p.parent();
                    } else {
                        if (nodeColor(w.left) == .black) { // case 4
                            w.setColor(.red);
                            self.rotateLeftWithRoot(w);
                            w = p.left.?;
                            w.setColor(.black);
                        }

                        // case 5
                        w.setColor(p.color());
                        p.setColor(.black);
                        w.left.?.setColor(.black);
                        self.rotateRightWithRoot(p);
                        x = self.root;
                        break;
                    }
                }
            }

            if (x) |node| { // case 0 and 2 when parent was red
                node.setColor(.black);
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

            switch (node.nodeType()) {
                .root => {
                    self.root = ptr;
                    self.root.?.setParent(null);
                },
                .left_child => node.parent().?.left = ptr,
                .right_child => node.parent().?.right = ptr,
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

            switch (node.nodeType()) {
                .root => {
                    self.root = ptr;
                    self.root.?.setParent(null);
                },
                .left_child => node.parent().?.left = ptr,
                .right_child => node.parent().?.right = ptr,
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
            return .black; // null is black
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

        pub fn isRedBlackTree(self: *const Self) bool {
            if (self.root == null) return true;

            const r = self.root.?;

            if (r.parent() != null) return false;
            if (r.color() != .black) return false;

            return blackHeight(self.root) != null;
        }

        pub fn debugPrint(self: *const Self, comptime use_color: bool) !void {
            var str = std.ArrayList(u8).init(std.heap.page_allocator);
            defer str.deinit();

            const writer = str.writer();

            if (self.root) |r| {
                if (use_color) {
                    const config = tty.detectConfig(std.io.getStdOut());
                    try tty.Config.setColor(config, writer, if (r.color() == .black) .black else .red);
                    try writer.print("{d:<3}", .{r.value});
                    try tty.Config.setColor(config, writer, .reset);
                } else {
                    try writer.print("{d:<3}(B)", .{r.value});
                }

                try traverseNodes(writer, r.right, "", "\\--", r.left != null, use_color);
                try traverseNodes(writer, r.left, "", "---", false, use_color);

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
            comptime use_color: bool,
        ) !void {
            const max_line_len = 1024;
            if (node) |n| {
                try writer.print("\n{s}{s}", .{ padding, pointer });

                if (use_color) {
                    const config = tty.detectConfig(std.io.getStdOut());
                    try tty.Config.setColor(config, writer, if (n.color() == .black) .black else .red);
                    try writer.print("{d:<3}", .{n.value});
                    try tty.Config.setColor(config, writer, .reset);
                } else {
                    try writer.print("{d:<3}{s}", .{ n.value, if (n.color() == .black) "(B)" else "(R)" });
                }

                var buffer = try std.BoundedArray(u8, max_line_len).init(0);
                const w = buffer.writer();
                _ = try w.write(padding);
                _ = try w.write(if (has_left_sibling) "|  " else "   ");

                try traverseNodes(writer, n.right, buffer.constSlice(), "\\--", n.left != null, use_color);
                try traverseNodes(writer, n.left, buffer.constSlice(), "---", false, use_color);
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

    try testing.expect(tree.isRedBlackTree());

    while (tree.size > 0) {
        const target = tree.root.?;
        tree.remove(target);
        testing.allocator.destroy(target);
    }

    for (0..node_count / 2) |_| {
        var node = try testing.allocator.create(T.Node);
        node.value = rand.int(i32);
        const res = tree.insert(node);
        if (res != null) {
            testing.allocator.destroy(node);
        }
    }

    while (tree.size > node_count / 4) {
        const target = tree.root.?;
        tree.remove(target);
        testing.allocator.destroy(target);
    }

    for (0..node_count / 2) |_| {
        var node = try testing.allocator.create(T.Node);
        node.value = rand.int(i32);
        const res = tree.insert(node);
        if (res != null) {
            testing.allocator.destroy(node);
        }
    }

    while (tree.size > node_count / 4) {
        const target = tree.root.?;
        tree.remove(target);
        testing.allocator.destroy(target);
    }

    while (tree.size > 0) {
        const target = tree.root.?;
        tree.remove(target);
        testing.allocator.destroy(target);
    }
}
