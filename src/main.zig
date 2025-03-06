const std = @import("std");

const Color = struct {
    value: enum(u4) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        default = 9,
    } = .default,
    bright: bool = false,

    pub const default: Color = .{
        .value = .default,
        .bright = false,
    };
};

const Style = struct {
    fg_color: Color = Color.default,
    bg_color: Color = Color.default,
    bold: bool = false,
    underlined: bool = false,

    pub const reset_str = "\x1b[0m";
};

const FormattedText = struct {
    pub fn init(text: []const u8, style: Style, allocator: std.mem.Allocator) !std.ArrayList(u8) {
        var styled_string = std.ArrayList(u8).init(allocator);
        var writer = styled_string.writer();
        const csi = "\x1b[";
        try writer.writeAll(csi);
        if (style.bold) {
            try writer.writeAll("1;");
        }
        if (style.underlined) {
            try writer.writeAll("4;");
        }
        if (style.fg_color.value != .default) {
            try writer.print("{s}{d};", .{
                if (style.fg_color.bright) "9" else "3",
                @intFromEnum(style.fg_color.value),
            });
        }
        if (style.bg_color.value != .default) {
            try writer.print("{s}{d};", .{
                if (style.bg_color.bright) "10" else "4",
                @intFromEnum(style.bg_color.value),
            });
        }
        try writer.writeByte('m');
        try writer.writeAll(text);
        try writer.writeAll(Style.reset_str);
        return styled_string;
    }
};

pub fn LinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            next: ?*Node = null,
            data: T,

            pub const Data = T;
        };

        first: ?*Node = null,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Semantic alias of `self.clear`
        pub fn deinit(self: *Self) void {
            self.clear();
        }

        /// Clears the list while freeing memory with `self.allocator.destroy`
        pub fn clear(self: *Self) void {
            while (self.first) {
                const first = self.popFirst() orelse unreachable;
                self.first = first.next;
                self.allocator.destroy(first);
            }
        }

        /// Appends data to the list using `self.allocator.create`
        pub fn prepend(self: *Self, data: T) !void {
            const first = self.first;
            const new_node = try self.allocator.create(Node);
            new_node.data = data;
            new_node.next = first;
            self.first = new_node;
        }

        /// Removes the first `Node` from the list, or null if the list is empty.
        /// Make sure to call `self.allocator.destroy` on the pointer to free memory.
        pub fn popFirst(self: *Self) ?*Node {
            const first = self.first orelse return null;
            const next = first.next;
            self.first = next;
            return first;
        }
    };
}

const Stack = struct {
    const T = f128;
    data: LinkedList(T),

    pub fn init(allocator: std.mem.Allocator) Stack {
        return .{
            .data = LinkedList(T).init(allocator),
        };
    }

    pub fn deinit(self: *Stack) void {
        self.data.deinit();
    }

    const StackOperationError = error{
        EmptyStack,
        InvalidOperandCount,
    };

    // pub fn processRPNString(self: *Stack, string: []u8) !void {
    //     var chunk_iterator = std.mem.splitSequence(u8, string, " ");
    //     while (try chunk_iterator.next()) |chunk| {
    //         var bufcursor: usize = 0;
    //         var numBuf: [128]u8 = undefined;
    //         var hasDecimal = false;
    //         var hasExponent = false;
    //         for (0..chunk.len) |i| {
    //             const char: u8 = chunk[i];
    //         }
    //     }
    // }

    /// Pops the top value on the stack and adds it to the next value
    pub fn add(self: *Stack) !void {
        if (self.data.first == null or self.data.first.?.next == null) {
            return StackOperationError.InvalidOperandCount;
        }

        const first = self.data.popFirst() orelse unreachable;
        defer self.data.allocator.destroy(first);

        var next = first.next orelse unreachable;

        next.data += first.data;
    }

    /// Adds `value` to the top value in the stack
    pub fn addValue(self: *Stack, value: T) !void {
        if (self.data.first == null) {
            return StackOperationError.EmptyStack;
        }
        self.data.first.?.data += value;
    }
};

fn repl(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    // buffer input & output
    var writer = stdout.writer();
    var reader = stdin.reader();

    const prompt = try FormattedText.init("> ", .{ .fg_color = .{ .value = .green }, .bold = true }, alloc);
    defer prompt.deinit();

    var input = std.ArrayList(u8).init(alloc);
    defer input.deinit();

    try writer.writeAll(prompt.items);

    reader.readUntilDelimiterArrayList(&input, '\n', 4096) catch |err| switch (err) {
        error.EndOfStream => return,
        else => return err,
    };

    try writer.print("{s}", .{input.items});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var args_iter = try std.process.argsWithAllocator(alloc);
    defer args_iter.deinit();

    var args = std.ArrayList([:0]const u8).init(alloc);
    defer args.deinit();

    var arg = args_iter.next();
    while (arg != null) : (arg = args_iter.next()) {
        try args.append(arg.?);
    }

    const arg_count: usize = args.items.len - 1;

    if (arg_count == 0) {
        try repl(alloc);
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
