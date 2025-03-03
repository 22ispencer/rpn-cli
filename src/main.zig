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
    },
    bright: bool,

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

    pub const reset_str = "\x1b[22;24;39;49m";
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

fn repl(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    // buffer input & output
    var writer = stdout.writer();
    var reader = stdin.reader();

    const prompt = try FormattedText.init("> ", Style.init(.{ .bright = false, .value = .green }, null, true, false), alloc);
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
